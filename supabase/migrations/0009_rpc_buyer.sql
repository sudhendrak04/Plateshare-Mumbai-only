-- Stage 3 · 0009_rpc_buyer — shared helpers + buyer RPCs (doc/05-api-spec.md §2)
-- All RPCs are SECURITY DEFINER and authorize the caller themselves.

-- ───────────────────────── shared helpers ─────────────────────────

create or replace function public.audit(
  p_entity text, p_entity_id text, p_action text,
  p_old jsonb default null, p_new jsonb default null
) returns void
language sql security definer set search_path = public
as $$
  insert into public.audit_logs (actor_id, actor_role, entity, entity_id, action, old_value, new_value)
  values (auth.uid(), public.app_role()::text, p_entity, p_entity_id, p_action, p_old, p_new);
$$;

create or replace function public.notify(
  p_template text, p_channel text, p_payload jsonb, p_dedupe text default null
) returns void
language sql security definer set search_path = public
as $$
  insert into public.outbox (channel, template_key, payload, dedupe_key)
  values (p_channel, p_template, p_payload, p_dedupe);
$$;

create or replace function public.cfg_int(p_key text)
returns int
language sql stable security definer set search_path = public
as $$
  select (value::text)::int from public.app_config where key = p_key
$$;

create or replace function public.cfg_date(p_key text)
returns date
language sql stable security definer set search_path = public
as $$
  select (value #>> '{}')::date from public.app_config where key = p_key
$$;

-- COD eligibility (doc/07 §1.2): trust score + minimum prior successful pickups
create or replace function public.cod_eligible(p_buyer uuid)
returns boolean
language plpgsql stable security definer set search_path = public
as $$
declare
  v_trust int;
  v_picked int;
begin
  select trust_score into v_trust from public.profiles where id = p_buyer;
  select count(*) into v_picked
  from public.orders where buyer_id = p_buyer and status = 'picked_up';

  return v_trust >= public.cfg_int('cod_threshold')
     and v_picked >= public.cfg_int('cod_min_orders');
end;
$$;

-- ───────────────────────── buyer RPCs ─────────────────────────

-- 🔴 reserve_order: atomic hold + COD gate (doc/05 §2, doc/07 §1)
create or replace function public.reserve_order(
  p_listing_id uuid, p_pay_method public.pay_method
) returns table (order_id uuid, expires_at timestamptz, amount_paise int, qr_token text, pickup_otp text)
language plpgsql security definer set search_path = public
as $$
declare
  v_buyer uuid := auth.uid();
  v_listing public.listings;
  v_expires timestamptz;
  v_order public.orders;
  v_token text;
  v_otp text;
begin
  if v_buyer is null then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  select * into v_listing from public.listings where id = p_listing_id for update;
  if not found then
    raise exception 'LISTING_NOT_FOUND' using errcode = 'P0001';
  end if;
  if v_listing.status <> 'live' or v_listing.closes_at <= now() then
    raise exception 'QTY_EXHAUSTED' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.restaurants r
    where r.id = v_listing.restaurant_id
      and (r.status <> 'verified' or (r.suspended_until is not null and r.suspended_until > now()))
  ) then
    raise exception 'VENDOR_SUSPENDED' using errcode = 'P0001';
  end if;

  if p_pay_method = 'cod' and not public.cod_eligible(v_buyer) then
    raise exception 'TRUST_TOO_LOW_FOR_COD' using errcode = 'P0001';
  end if;

  update public.listings
  set qty_left = qty_left - 1
  where id = p_listing_id and qty_left > 0;
  if not found then
    raise exception 'QTY_EXHAUSTED' using errcode = 'P0001';
  end if;

  v_token := encode(extensions.digest(v_buyer::text || extensions.gen_random_uuid()::text, 'sha256'), 'hex');
  v_otp   := lpad((floor(random() * 1000000))::int::text, 6, '0');

  -- prepaid hold = 10 min; COD hold = until 15 min before window end (doc/07 §1.2)
  v_expires := case
    when p_pay_method = 'cod' then v_listing.closes_at - interval '15 minutes'
    else now() + interval '10 minutes'
  end;

  insert into public.orders
    (buyer_id, listing_id, qty, amount_paise, pay_method, status, expires_at, qr_token, pickup_otp)
  values
    (v_buyer, p_listing_id, 1, v_listing.price_paise, p_pay_method, 'reserved', v_expires, v_token, v_otp)
  returning * into v_order;

  perform public.audit('orders', v_order.id::text, 'reserved', null,
    jsonb_build_object('listing', p_listing_id, 'pay_method', p_pay_method, 'amount', v_listing.price_paise));

  if p_pay_method = 'cod' then
    perform public.notify('N8_new_order_vendor', 'push',
      jsonb_build_object('order_id', v_order.id, 'listing', p_listing_id, 'pay', 'COD'),
      'ord:' || v_order.id || ':b1:push');
    perform public.notify('N8_new_order_vendor', 'whatsapp',
      jsonb_build_object('order_id', v_order.id, 'pay', 'COD'),
      'ord:' || v_order.id || ':b1:wa');
  end if;

  return query select v_order.id, v_expires, v_listing.price_paise, v_token, v_otp;
end;
$$;

-- cancel while reserved → release hold (doc/07 §2)
create or replace function public.cancel_order(p_order_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders;
begin
  select * into v_order from public.orders
  where id = p_order_id and buyer_id = auth.uid() and status = 'reserved';
  if not found then
    raise exception 'ORDER_NOT_CANCELLABLE' using errcode = 'P0001';
  end if;

  update public.orders set status = 'cancelled' where id = p_order_id;
  update public.listings
  set qty_left = least(qty_total, qty_left + v_order.qty)
  where id = v_order.listing_id;

  if (select qty_left from public.listings where id = v_order.listing_id) > 0
     and (select status from public.listings where id = v_order.listing_id) = 'sold_out' then
    update public.listings set status = 'live' where id = v_order.listing_id;
  end if;

  perform public.audit('orders', p_order_id::text, 'cancelled', '{"status":"reserved"}', '{"status":"cancelled"}');
end;
$$;

-- rating after pickup (one per order)
create or replace function public.rate_order(
  p_order_id uuid, p_stars int, p_tags text[] default '{}', p_comment text default null
) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.buyer_id = auth.uid() and o.status = 'picked_up'
  ) then
    raise exception 'RATING_NOT_ALLOWED' using errcode = 'P0001';
  end if;
  if p_stars < 1 or p_stars > 5 then
    raise exception 'STARS_INVALID' using errcode = 'P0001';
  end if;

  begin
    insert into public.ratings (order_id, stars, tags, comment)
    values (p_order_id, p_stars, p_tags, p_comment);
  exception when unique_violation then
    raise exception 'ALREADY_RATED' using errcode = 'P0001';
  end;

  perform public.audit('ratings', p_order_id::text, 'rated', null, jsonb_build_object('stars', p_stars));
end;
$$;

-- report-a-problem (refund-first policy — dispute handled in admin console)
create or replace function public.report_incident(
  p_order_id uuid, p_type public.incident_type, p_evidence_url text default null
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_incident uuid;
begin
  if not exists (
    select 1 from public.orders o
    where o.id = p_order_id and o.buyer_id = auth.uid() and o.status = 'picked_up'
  ) then
    raise exception 'INCIDENT_NOT_ALLOWED' using errcode = 'P0001';
  end if;

  insert into public.incidents (order_id, type, evidence_url)
  values (p_order_id, p_type, p_evidence_url)
  returning id into v_incident;

  perform public.audit('incidents', v_incident::text, 'opened', null,
    jsonb_build_object('order', p_order_id, 'type', p_type));

  return v_incident;
end;
$$;

-- 🔴 discovery: geo + filters (doc/04 §5)
create or replace function public.nearby_listings(
  p_lat double precision, p_lng double precision,
  p_radius_m int default 2000,
  p_category public.listing_category default null,
  p_max_price_paise int default null
)
returns table (
  listing_id uuid, restaurant_id uuid, restaurant_name text, restaurant_rating numeric,
  category public.listing_category, contents_hint text, price_paise int,
  original_value_paise int, photo_url text, prep_time timestamptz, consume_by timestamptz,
  window_start timestamptz, window_end timestamptz, grace_min int, qty_left int,
  distance_m double precision
)
language sql security definer set search_path = public
as $$
  select l.id, r.id, r.name, r.rating_avg, l.category, l.contents_hint, l.price_paise,
         l.original_value_paise, l.photo_url, l.prep_time, l.consume_by,
         w.start_at, w.end_at, w.grace_min, l.qty_left,
         extensions.st_distance(r.geo, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326))
  from public.listings l
  join public.restaurants r on r.id = l.restaurant_id
  join public.pickup_windows w on w.listing_id = l.id
  where l.status = 'live'
    and l.closes_at > now()
    and l.qty_left > 0
    and r.status = 'verified'
    and (r.suspended_until is null or r.suspended_until <= now())
    and (p_category is null or l.category = p_category)
    and (p_max_price_paise is null or l.price_paise <= p_max_price_paise)
    and extensions.st_dwithin(
      r.geo, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326), p_radius_m)
  order by l.closes_at asc, 16 asc
  limit 50
$$;

grant execute on function public.reserve_order(uuid, public.pay_method) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.rate_order(uuid, int, text[], text) to authenticated;
grant execute on function public.report_incident(uuid, public.incident_type, text) to authenticated;
grant execute on function public.nearby_listings(double precision, double precision, int, public.listing_category, int) to authenticated;
