-- Stage 2 · 0008_triggers — auth→profile, updated_at, freshness guard, window sync, rating recompute

-- 1. auth.users → profiles auto-create (role only from server-side app metadata)
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone, name, role)
  values (
    new.id,
    new.phone,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    coalesce(nullif(new.raw_app_meta_data ->> 'role', ''), 'buyer')::public.user_role
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. updated_at auto-touch (moddatetime)
create trigger touch_profiles before update on public.profiles
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_restaurants before update on public.restaurants
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_listings before update on public.listings
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_pickup_windows before update on public.pickup_windows
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_orders before update on public.orders
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_payments before update on public.payments
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_payouts before update on public.payouts
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_ngos before update on public.ngos
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_donations before update on public.donations
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_incidents before update on public.incidents
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_outbox before update on public.outbox
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger touch_app_config before update on public.app_config
  for each row execute procedure extensions.moddatetime (updated_at);

-- 3. Freshness/photo guard: a listing may only go live with full evidence
-- (doc/03 §3.3, doc/09 QA layer 3)
create or replace function public.enforce_live_listing()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'live' then
    if new.photo_url is null or new.photo_taken_at is null or new.photo_geo is null then
      raise exception 'PHOTO_REQUIRED: live listings need a validated in-app photo'
        using errcode = 'check_violation';
    end if;
    if exists (
      select 1 from public.restaurants r
      where r.id = new.restaurant_id and r.status <> 'verified'
    ) then
      raise exception 'VENDOR_NOT_VERIFIED: restaurant must be verified to publish'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger listings_live_guard
  before insert or update of status on public.listings
  for each row execute function public.enforce_live_listing();

-- 4. pickup_windows sync → listings.closes_at (denormalized for fast ordering)
create or replace function public.sync_listing_closes_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  update public.listings
  set closes_at = new.end_at
  where id = new.listing_id;
  return new;
end;
$$;

create trigger pickup_window_sync
  after insert or update of end_at on public.pickup_windows
  for each row execute function public.sync_listing_closes_at();

-- 5. ratings → recompute restaurants.rating_avg
create or replace function public.recompute_restaurant_rating()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_restaurant uuid;
begin
  select l.restaurant_id into v_restaurant
  from public.listings l
  join public.orders o on o.listing_id = l.id
  where o.id = new.order_id;

  if v_restaurant is not null then
    update public.restaurants r
    set rating_avg = coalesce((
      select round(avg(r2.stars)::numeric, 2)
      from public.ratings r2
      join public.orders o2 on o2.id = r2.order_id
      join public.listings l2 on l2.id = o2.listing_id
      where l2.restaurant_id = v_restaurant
    ), 0)
    where r.id = v_restaurant;
  end if;
  return new;
end;
$$;

create trigger ratings_update_restaurant
  after insert or update on public.ratings
  for each row execute function public.recompute_restaurant_rating();

-- 6. audit_logs append-only guard (even service role cannot modify history)
create or replace function public.audit_logs_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception 'AUDIT_IMMUTABLE: audit_logs is append-only'
    using errcode = 'check_violation';
end;
$$;

create trigger audit_logs_no_update
  before update on public.audit_logs
  for each row execute function public.audit_logs_immutable();

create trigger audit_logs_no_delete
  before delete on public.audit_logs
  for each row execute function public.audit_logs_immutable();
