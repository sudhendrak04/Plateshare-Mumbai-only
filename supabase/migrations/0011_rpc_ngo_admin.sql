-- Stage 3 · 0011_rpc_ngo_admin — NGO + Admin RPCs (doc/05-api-spec.md §4–5)

-- ───────────────────────── NGO ─────────────────────────

create or replace function public.ngo_apply(
  p_name text, p_reg_12a text, p_reg_80g text, p_darpan_id text,
  p_lat double precision, p_lng double precision
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;
  if exists (select 1 from public.ngos where contact_user_id = auth.uid()) then
    raise exception 'NGO_ALREADY_REGISTERED' using errcode = 'P0001';
  end if;

  insert into public.ngos
    (contact_user_id, name, reg_12a, reg_80g, darpan_id, geo, verified)
  values
    (auth.uid(), p_name, p_reg_12a, p_reg_80g, p_darpan_id,
     extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326), false)
  returning id into v_id;

  perform public.audit('ngos', v_id::text, 'applied', null, jsonb_build_object('name', p_name));
  return v_id;
end;
$$;

-- live donation broadcasts within 5 km (doc/02 §3.2)
create or replace function public.ngo_open_donations(
  p_lat double precision, p_lng double precision, p_radius_m int default 5000
)
returns table (donation_id uuid, listing_id uuid, restaurant_name text, qty_left int, broadcast_at timestamptz)
language sql security definer set search_path = public
as $$
  select d.id, d.listing_id, r.name, l.qty_left, d.created_at
  from public.donations d
  join public.listings l on l.id = d.listing_id
  join public.restaurants r on r.id = l.restaurant_id
  where d.ngo_id is null
    and l.status = 'donated'
    and exists (
      select 1 from public.ngos n
      where n.contact_user_id = auth.uid() and n.verified
    )
    and extensions.st_dwithin(
      r.geo, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326), p_radius_m)
  order by d.created_at
$$;

-- 🔴 atomic claim — single winner (doc/02 §3.2)
create or replace function public.claim_donation(p_donation_id uuid)
returns timestamptz
language plpgsql security definer set search_path = public
as $$
declare
  v_ngo uuid;
  v_claim_expires timestamptz;
begin
  select id into v_ngo from public.ngos
  where contact_user_id = auth.uid() and verified;
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  update public.donations
  set ngo_id = v_ngo,
      claimed_at = now(),
      claim_expires_at = now() + interval '30 minutes'
  where id = p_donation_id
    and ngo_id is null
    and picked_up_at is null
  returning claim_expires_at into v_claim_expires;

  if not found then
    raise exception 'ALREADY_CLAIMED' using errcode = 'P0001';
  end if;

  perform public.notify('N11_donation_claim_result', 'push',
    jsonb_build_object('donation_id', p_donation_id),
    'don:' || p_donation_id::text || ':claimed');

  perform public.audit('donations', p_donation_id::text, 'claimed', null,
    jsonb_build_object('ngo', v_ngo));

  return v_claim_expires;
end;
$$;

create or replace function public.confirm_donation_pickup(p_donation_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.donations
  set picked_up_at = now()
  where id = p_donation_id
    and ngo_id = (select id from public.ngos where contact_user_id = auth.uid())
    and picked_up_at is null;
  if not found then
    raise exception 'PICKUP_NOT_ALLOWED' using errcode = 'P0001';
  end if;

  perform public.audit('donations', p_donation_id::text, 'picked_up', null, '{"picked_up":true}');
end;
$$;

create or replace function public.report_beneficiaries(p_donation_id uuid, p_count int)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_count < 0 then
    raise exception 'COUNT_INVALID' using errcode = 'P0001';
  end if;

  update public.donations
  set beneficiary_count = p_count
  where id = p_donation_id
    and ngo_id = (select id from public.ngos where contact_user_id = auth.uid());
  if not found then
    raise exception 'DONATION_NOT_YOURS' using errcode = 'P0001';
  end if;

  perform public.audit('donations', p_donation_id::text, 'beneficiaries_reported', null,
    jsonb_build_object('count', p_count));
end;
$$;

-- ───────────────────────── Admin ─────────────────────────
-- Every admin RPC verifies role='admin' (never trusts the client).

create or replace function public.admin_verify_vendor(
  p_restaurant_id uuid, p_approve boolean, p_reason text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_rest public.restaurants;
  v_owner uuid;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;

  select * into v_rest from public.restaurants where id = p_restaurant_id;
  if not found then
    raise exception 'RESTAURANT_NOT_FOUND' using errcode = 'P0001';
  end if;
  v_owner := v_rest.owner_user_id;

  update public.restaurants
  set status = case when p_approve then 'verified' else 'rejected' end
  where id = p_restaurant_id;

  perform public.notify('N14_vendor_verification', 'push',
    jsonb_build_object('restaurant_id', p_restaurant_id, 'result', case when p_approve then 'approved' else 'rejected' end, 'reason', p_reason),
    'rest:' || p_restaurant_id::text || ':verify:push');
  perform public.notify('N14_vendor_verification', 'whatsapp',
    jsonb_build_object('result', case when p_approve then 'approved' else 'rejected' end, 'reason', p_reason),
    'rest:' || p_restaurant_id::text || ':verify:wa');

  perform public.audit('restaurants', p_restaurant_id::text,
    case when p_approve then 'verified' else 'rejected' end,
    jsonb_build_object('status', v_rest.status), jsonb_build_object('status', case when p_approve then 'verified' else 'rejected' end, 'reason', p_reason));
end;
$$;

create or replace function public.admin_verify_ngo(
  p_ngo_id uuid, p_approve boolean, p_reason text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ngo public.ngos;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;

  select * into v_ngo from public.ngos where id = p_ngo_id;
  if not found then
    raise exception 'NGO_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.ngos
  set verified = p_approve,
      verified_at = case when p_approve then now() else null end
  where id = p_ngo_id;

  perform public.audit('ngos', p_ngo_id::text, case when p_approve then 'verified' else 'rejected' end,
    jsonb_build_object('verified', v_ngo.verified), jsonb_build_object('verified', p_approve, 'reason', p_reason));
end;
$$;

-- dispute resolution + suspension ladder (doc/02 §4.1)
create or replace function public.admin_resolve_incident(
  p_incident_id uuid, p_action text, p_note text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_incident public.incidents;
  v_order public.orders;
  v_restaurant uuid;
  v_until timestamptz;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;

  select * into v_incident from public.incidents where id = p_incident_id;
  if not found then
    raise exception 'INCIDENT_NOT_FOUND' using errcode = 'P0001';
  end if;

  select * into v_order from public.orders where id = v_incident.order_id;
  select restaurant_id into v_restaurant from public.listings where id = v_order.listing_id;

  case p_action
    when 'refund' then
      update public.incidents set status = 'resolved_refund', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
      update public.orders set status = 'refunded' where id = v_order.id;
      update public.payments set status = 'refunded' where order_id = v_order.id;
      perform public.notify('refund_request', 'razorpay',
        jsonb_build_object('order_id', v_order.id, 'amount', v_order.amount_paise, 'reason', p_note),
        'inc:' || p_incident_id::text || ':refund');
    when 'warning' then
      update public.incidents set status = 'resolved_warning', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
    when 'delist7' then
      update public.incidents set status = 'resolved_warning', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
      update public.restaurants set suspended_until = now() + interval '7 days' where id = v_restaurant;
      update public.listings set status = 'expired' where restaurant_id = v_restaurant and status = 'live';
    when 'delist30' then
      update public.incidents set status = 'resolved_warning', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
      update public.restaurants set suspended_until = now() + interval '30 days' where id = v_restaurant;
      update public.listings set status = 'expired' where restaurant_id = v_restaurant and status = 'live';
    when 'ban' then
      update public.incidents set status = 'resolved_warning', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
      update public.restaurants set status = 'suspended' where id = v_restaurant;
      update public.listings set status = 'expired' where restaurant_id = v_restaurant and status = 'live';
    when 'dismiss' then
      update public.incidents set status = 'dismissed', resolution_note = p_note,
        resolved_by = auth.uid() where id = p_incident_id;
    else
      raise exception 'ACTION_INVALID' using errcode = 'P0001';
  end case;

  perform public.audit('incidents', p_incident_id::text, 'resolved_' || p_action,
    jsonb_build_object('status', v_incident.status), jsonb_build_object('action', p_action, 'note', p_note));
end;
$$;

-- ops dashboard per-cluster for a date (doc/02 §4.2)
create or replace function public.admin_ops_dashboard(p_day date default current_date)
returns table (
  cluster_name text, listed int, sold int, donated int, wasted int,
  sell_through numeric, gmv_paise int
)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;

  return query
  select c.name,
    coalesce(lstd.cnt, 0)::int,
    coalesce(sold.cnt, 0)::int,
    coalesce(don.cnt, 0)::int,
    coalesce(wast.cnt, 0)::int,
    case when coalesce(lstd.qty, 0) = 0 then 0
         else round(coalesce(sold.qty, 0)::numeric / lstd.qty, 2) end,
    coalesce(gmv.amt, 0)::int
  from public.clusters c
  left join lateral (
    select count(*) as cnt, coalesce(sum(l.qty_total), 0) as qty
    from public.listings l join public.restaurants r on r.id = l.restaurant_id
    where l.created_at::date = p_day
      and extensions.st_dwithin(c.center, r.geo, c.radius_m)
  ) lstd on true
  left join lateral (
    select count(*) as cnt, coalesce(sum(o.qty), 0) as qty
    from public.orders o
    join public.listings l on l.id = o.listing_id
    join public.restaurants r on r.id = l.restaurant_id
    where o.status = 'picked_up' and o.picked_up_at::date = p_day
      and extensions.st_dwithin(c.center, r.geo, c.radius_m)
  ) sold on true
  left join lateral (
    select count(*) as cnt
    from public.donations d
    join public.listings l on l.id = d.listing_id
    join public.restaurants r on r.id = l.restaurant_id
    where l.donated_at::date = p_day
      and extensions.st_dwithin(c.center, r.geo, c.radius_m)
  ) don on true
  left join lateral (
    select count(*) as cnt
    from public.listings l join public.restaurants r on r.id = l.restaurant_id
    where l.status = 'wasted' and l.wasted_at::date = p_day
      and extensions.st_dwithin(c.center, r.geo, c.radius_m)
  ) wast on true
  left join lateral (
    select coalesce(sum(o.amount_paise), 0) as amt
    from public.orders o
    join public.listings l on l.id = o.listing_id
    join public.restaurants r on r.id = l.restaurant_id
    where o.status = 'picked_up' and o.picked_up_at::date = p_day
      and extensions.st_dwithin(c.center, r.geo, c.radius_m)
  ) gmv on true
  where c.is_active;
end;
$$;

-- GST ledger export (model-agnostic; doc/07 §4)
create or replace function public.admin_gst_ledger(p_month date)
returns table (order_id uuid, amount_paise int, gst_collected_paise int, captured_at timestamptz)
language sql security definer set search_path = public
as $$
  select p.order_id, p.amount_paise, p.gst_collected_paise, p.updated_at
  from public.payments p
  where p.status in ('captured', 'refunded')
    and date_trunc('month', p.updated_at) = date_trunc('month', p_month)
$$;

grant execute on function public.ngo_apply(text, text, text, text, double precision, double precision) to authenticated;
grant execute on function public.ngo_open_donations(double precision, double precision, int) to authenticated;
grant execute on function public.claim_donation(uuid) to authenticated;
grant execute on function public.confirm_donation_pickup(uuid) to authenticated;
grant execute on function public.report_beneficiaries(uuid, int) to authenticated;
grant execute on function public.admin_verify_vendor(uuid, boolean, text) to authenticated;
grant execute on function public.admin_verify_ngo(uuid, boolean, text) to authenticated;
grant execute on function public.admin_resolve_incident(uuid, text, text) to authenticated;
grant execute on function public.admin_ops_dashboard(date) to authenticated;
grant execute on function public.admin_gst_ledger(date) to authenticated;
