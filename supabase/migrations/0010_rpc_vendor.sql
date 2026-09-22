-- Stage 3 · 0010_rpc_vendor — vendor RPCs (doc/05-api-spec.md §3)
-- All RPCs SECURITY DEFINER; caller must own the restaurant.

-- register restaurant (status pending; admin verifies)
create or replace function public.register_restaurant(
  p_name text, p_fssai_license text,
  p_cuisine_tags text[] default '{}',
  p_fssai_expiry_date date default null,
  p_gstin text default null, p_address text default null,
  p_lat double precision default null, p_lng double precision default null,
  p_open_time time default '10:00', p_close_time time default '22:00',
  p_food_type public.food_type default 'veg_nonveg', p_payout_upi text default null
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;
  if p_fssai_license !~ '^[0-9]{14}$' then
    raise exception 'FSSAI_INVALID' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.restaurants where owner_user_id = auth.uid()) then
    raise exception 'VENDOR_ALREADY_REGISTERED' using errcode = 'P0001';
  end if;

  insert into public.restaurants
    (owner_user_id, name, cuisine_tags, fssai_license, fssai_expiry_date, gstin,
     address, geo, open_time, close_time, food_type, payout_upi, status)
  values
    (auth.uid(), p_name, p_cuisine_tags, p_fssai_license, p_fssai_expiry_date, p_gstin,
     p_address, extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326),
     p_open_time, p_close_time, p_food_type, p_payout_upi, 'pending')
  returning id into v_id;

  perform public.audit('restaurants', v_id::text, 'registered', null,
    jsonb_build_object('name', p_name, 'fssai', p_fssai_license));

  return v_id;
end;
$$;

-- 🔴 create_listing: server re-validates everything (doc/09 layers 2–4)
create or replace function public.create_listing(
  p_category public.listing_category, p_qty_total int,
  p_original_value_paise int, p_price_paise int,
  p_contents_hint text,
  p_photo_url text, p_photo_lat double precision, p_photo_lng double precision,
  p_photo_taken_at timestamptz,
  p_prep_time timestamptz, p_consume_by timestamptz,
  p_window_start timestamptz, p_window_end timestamptz,
  p_grace_min int default null
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_rest public.restaurants;
  v_id uuid;
  v_grace int;
begin
  select * into v_rest from public.restaurants where owner_user_id = auth.uid();
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;
  if v_rest.status <> 'verified' or (v_rest.suspended_until is not null and v_rest.suspended_until > now()) then
    raise exception 'VENDOR_SUSPENDED' using errcode = 'P0001';
  end if;
  if v_rest.fssai_expiry_date is not null and v_rest.fssai_expiry_date < current_date then
    raise exception 'FSSAI_EXPIRED' using errcode = 'P0001';
  end if;

  if p_qty_total < 1 then
    raise exception 'QTY_INVALID' using errcode = 'P0001';
  end if;
  if p_price_paise < public.cfg_int('price_floor_paise') then
    raise exception 'PRICE_FLOOR' using errcode = 'P0001';
  end if;
  if p_price_paise * 2 > p_original_value_paise then
    raise exception 'DISCOUNT_TOO_SMALL' using errcode = 'P0001';
  end if;
  if p_consume_by <= p_prep_time then
    raise exception 'FRESHNESS_INVALID' using errcode = 'P0001';
  end if;
  if p_photo_url is null or p_photo_taken_at is null then
    raise exception 'PHOTO_EXIF_INVALID' using errcode = 'P0001';
  end if;
  if p_window_end <= p_window_start then
    raise exception 'WINDOW_INVALID' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.blocked_categories bc
    where bc.is_active
      and (p_contents_hint ilike '%' || bc.pattern || '%')
  ) then
    raise exception 'CATEGORY_BLOCKED' using errcode = 'P0001';
  end if;

  v_grace := coalesce(p_grace_min, public.cfg_int('grace_default_min'));

  insert into public.listings
    (restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
     contents_hint, photo_url, photo_geo, photo_taken_at, prep_time, consume_by,
     closes_at, status)
  values
    (v_rest.id, p_category, p_qty_total, p_qty_total, p_original_value_paise, p_price_paise,
     p_contents_hint, p_photo_url,
     extensions.st_setsrid(extensions.st_makepoint(p_photo_lng, p_photo_lat), 4326),
     p_photo_taken_at, p_prep_time, p_consume_by, p_window_end, 'live')
  returning id into v_id;

  insert into public.pickup_windows (listing_id, start_at, end_at, grace_min)
  values (v_id, p_window_start, p_window_end, v_grace);

  perform public.audit('listings', v_id::text, 'published', null,
    jsonb_build_object('restaurant', v_rest.id, 'category', p_category, 'price', p_price_paise));

  return v_id;
end;
$$;

-- adjust inventory (never below already-sold)
create or replace function public.update_listing_qty(p_listing_id uuid, p_new_qty_total int)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_listing public.listings;
  v_sold int;
begin
  select * into v_listing from public.listings
  where id = p_listing_id
    and exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    );
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  v_sold := v_listing.qty_total - v_listing.qty_left;
  if p_new_qty_total < v_sold then
    raise exception 'QTY_BELOW_SOLD' using errcode = 'P0001';
  end if;

  update public.listings
  set qty_total = p_new_qty_total,
      qty_left = p_new_qty_total - v_sold,
      status = case when p_new_qty_total - v_sold > 0 and status = 'sold_out' then 'live' else status end
  where id = p_listing_id;

  perform public.audit('listings', p_listing_id::text, 'qty_updated',
    jsonb_build_object('qty_total', v_listing.qty_total), jsonb_build_object('qty_total', p_new_qty_total));
end;
$$;

-- sold out
create or replace function public.mark_sold_out(p_listing_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_listing public.listings;
begin
  select * into v_listing from public.listings
  where id = p_listing_id
    and exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    );
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  update public.listings
  set status = 'sold_out', qty_left = 0
  where id = p_listing_id and status = 'live';

  perform public.audit('listings', p_listing_id::text, 'sold_out',
    jsonb_build_object('status', v_listing.status), '{"status":"sold_out"}');
end;
$$;

-- 🔴 confirm_pickup: QR/OTP + window validation (doc/05 §3)
create or replace function public.confirm_pickup(
  p_order_id uuid, p_qr_token text default null, p_otp text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_order public.orders;
  v_listing public.listings;
  v_window public.pickup_windows;
  v_rest uuid;
begin
  select l.restaurant_id into v_rest
  from public.orders o join public.listings l on l.id = o.listing_id
  where o.id = p_order_id;

  if not exists (
    select 1 from public.restaurants r
    where r.id = v_rest and r.owner_user_id = auth.uid()
  ) and not public.is_admin() then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  select * into v_order from public.orders where id = p_order_id;
  select * into v_listing from public.listings where id = v_order.listing_id;
  select * into v_window from public.pickup_windows where listing_id = v_order.listing_id;

  if (p_qr_token is null or v_order.qr_token is distinct from p_qr_token)
     and (p_otp is null or v_order.pickup_otp is distinct from p_otp) then
    raise exception 'QR_INVALID' using errcode = 'P0001';
  end if;

  if now() < v_window.start_at
     or now() > v_window.end_at + (v_window.grace_min * interval '1 minute') then
    raise exception 'WINDOW_CLOSED' using errcode = 'P0001';
  end if;

  if v_order.pay_method = 'prepaid_upi' then
    if v_order.status <> 'paid' then
      raise exception 'NOT_PAID' using errcode = 'P0001';
    end if;
  else
    if v_order.status <> 'reserved' then
      raise exception 'ORDER_NOT_CONFIRMABLE' using errcode = 'P0001';
    end if;
  end if;

  update public.orders
  set status = 'picked_up', picked_up_at = now(),
      cod_collected = (pay_method = 'cod')
  where id = p_order_id;

  perform public.audit('orders', p_order_id::text, 'picked_up',
    jsonb_build_object('status', v_order.status), '{"status":"picked_up"}');
end;
$$;

-- donate unsold at window close (FSSAI 2019 donation trail; doc/02 §3.2)
create or replace function public.donate_leftover(p_listing_id uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_listing public.listings;
  v_donation uuid;
begin
  select * into v_listing from public.listings
  where id = p_listing_id
    and exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    );
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  if not (v_listing.status = 'expired'
      or (v_listing.status = 'live' and v_listing.closes_at < now())) then
    raise exception 'DONATE_NOT_ALLOWED' using errcode = 'P0001';
  end if;
  if v_listing.qty_left = 0 then
    raise exception 'NOTHING_TO_DONATE' using errcode = 'P0001';
  end if;

  update public.listings
  set status = 'donated', donated_at = now()
  where id = p_listing_id;

  insert into public.donations (listing_id, broadcast_count)
  values (p_listing_id, 1)
  returning id into v_donation;

  perform public.notify('N10_donation_broadcast', 'push',
    jsonb_build_object('listing_id', p_listing_id, 'donation_id', v_donation, 'qty', v_listing.qty_left),
    'don:' || v_donation::text || ':b1:push');
  perform public.notify('N10_donation_broadcast', 'whatsapp',
    jsonb_build_object('donation_id', v_donation, 'qty', v_listing.qty_left),
    'don:' || v_donation::text || ':b1:wa');

  perform public.audit('listings', p_listing_id::text, 'donated',
    jsonb_build_object('status', v_listing.status), '{"status":"donated"}');

  return v_donation;
end;
$$;

-- vendor stats (doc/02 §1.3)
create or replace function public.vendor_stats(p_from date default current_date, p_to date default current_date)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_rest uuid;
begin
  select id into v_rest from public.restaurants where owner_user_id = auth.uid();
  if not found then
    raise exception 'UNAUTHORIZED' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'listed', (select count(*) from public.listings
               where restaurant_id = v_rest and created_at::date between p_from and p_to),
    'sold', (select coalesce(sum(o.qty), 0) from public.orders o
             join public.listings l on l.id = o.listing_id
             where l.restaurant_id = v_rest and o.status = 'picked_up'
               and o.picked_up_at::date between p_from and p_to),
    'donated', (select count(*) from public.donations d
                join public.listings l on l.id = d.listing_id
                where l.restaurant_id = v_rest and l.donated_at::date between p_from and p_to),
    'wasted', (select count(*) from public.listings
               where restaurant_id = v_rest and status = 'wasted'
                 and wasted_at::date between p_from and p_to),
    'revenue_paise', (select coalesce(sum(o.amount_paise), 0) from public.orders o
                      join public.listings l on l.id = o.listing_id
                      where l.restaurant_id = v_rest and o.status = 'picked_up'
                        and o.picked_up_at::date between p_from and p_to)
  );
end;
$$;

-- vendor payout history
create or replace function public.vendor_payouts()
returns table (id uuid, period_start date, period_end date, gross_paise int,
               commission_paise int, cod_commission_paise int, net_paise int,
               status public.payout_status, batch_ref text)
language sql security definer set search_path = public
as $$
  select p.id, p.period_start, p.period_end, p.gross_paise, p.commission_paise,
         p.cod_commission_paise, p.net_paise, p.status, p.batch_ref
  from public.payouts p
  join public.restaurants r on r.id = p.restaurant_id
  where r.owner_user_id = auth.uid()
  order by p.period_start desc
$$;

grant execute on function public.register_restaurant(text, text, text[], date, text, text, double precision, double precision, time, time, public.food_type, text) to authenticated;
grant execute on function public.create_listing(public.listing_category, int, int, int, text, text, double precision, double precision, timestamptz, timestamptz, timestamptz, timestamptz, timestamptz, int) to authenticated;
grant execute on function public.update_listing_qty(uuid, int) to authenticated;
grant execute on function public.mark_sold_out(uuid) to authenticated;
grant execute on function public.confirm_pickup(uuid, text, text) to authenticated;
grant execute on function public.donate_leftover(uuid) to authenticated;
grant execute on function public.vendor_stats(date, date) to authenticated;
grant execute on function public.vendor_payouts() to authenticated;
