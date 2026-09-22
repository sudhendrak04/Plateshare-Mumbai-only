-- Stage 2 · 0007_rls — default-deny + policies (backend/backend_plan.md §6)
-- Helper functions: security definer so policies never recurse on profiles.

create or replace function public.app_role()
returns public.user_role
language sql stable security definer
set search_path = public
as $$
  select coalesce((
    select p.role from public.profiles p where p.id = auth.uid()
  ), 'buyer'::public.user_role)
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.app_role() = 'admin'
$$;

create or replace function public.is_vendor_owner(r public.restaurants)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select r.owner_user_id = auth.uid()
$$;

-- Security-definer helper: bypasses RLS to avoid policy recursion
-- (orders → listings → orders). Callers pass a listing_id; the entire
-- lookup happens inside the function, so no nested RLS evaluation occurs.
create or replace function public.is_vendor_for_listing(l_uuid uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.restaurants r
    where r.id = (
      select restaurant_id from public.listings where id = l_uuid
    )
      and r.owner_user_id = auth.uid()
  )
$$;

create or replace function public.has_trusted_service_role()
returns boolean
language sql stable
as $$
  select auth.role() = 'service_role'
$$;

alter table public.profiles enable row level security;
alter table public.clusters enable row level security;
alter table public.restaurants enable row level security;
alter table public.listings enable row level security;
alter table public.pickup_windows enable row level security;
alter table public.blocked_categories enable row level security;
alter table public.orders enable row level security;
alter table public.payments enable row level security;
alter table public.payouts enable row level security;
alter table public.ngos enable row level security;
alter table public.donations enable row level security;
alter table public.ratings enable row level security;
alter table public.incidents enable row level security;
alter table public.outbox enable row level security;
alter table public.audit_logs enable row level security;
alter table public.app_config enable row level security;
alter table public.notification_templates enable row level security;

-- profiles
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid() or public.is_admin());
create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_admin_all on public.profiles
  for all using (public.is_admin()) with check (public.is_admin());

-- clusters
create policy clusters_read on public.clusters
  for select using (auth.uid() is not null or public.is_admin());
create policy clusters_admin_write on public.clusters
  for all using (public.is_admin()) with check (public.is_admin());

-- restaurants
create policy restaurants_select on public.restaurants
  for select using (
    status = 'verified'
    or owner_user_id = auth.uid()
    or public.is_admin()
  );
create policy restaurants_insert_own on public.restaurants
  for insert with check (owner_user_id = auth.uid() and status = 'pending');
create policy restaurants_update_own on public.restaurants
  for update using (owner_user_id = auth.uid() or public.is_admin())
  with check (owner_user_id = auth.uid() or public.is_admin());

-- listings
create policy listings_select on public.listings
  for select using (
    exists (
      select 1 from public.restaurants r
      where r.id = listings.restaurant_id
        and (r.status = 'verified' or r.owner_user_id = auth.uid())
    )
    and (
      listings.status in ('live', 'sold_out')
      or exists (
        select 1 from public.restaurants r
        where r.id = listings.restaurant_id and r.owner_user_id = auth.uid()
      )
      or public.is_admin()
    )
    or exists (
      select 1 from public.orders o
      where o.listing_id = listings.id and o.buyer_id = auth.uid()
    )
  );
create policy listings_insert_vendor on public.listings
  for insert with check (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    )
  );
create policy listings_update_vendor on public.listings
  for update using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    )
    or public.is_admin()
  );

-- pickup_windows (visibility follows the listing)
create policy pickup_windows_select on public.pickup_windows
  for select using (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and (
        l.status in ('live', 'sold_out')
        or exists (
          select 1 from public.restaurants r
          where r.id = l.restaurant_id and r.owner_user_id = auth.uid()
        )
        or public.is_admin()
      )
    )
  );
create policy pickup_windows_write_vendor on public.pickup_windows
  for all using (
    exists (
      select 1 from public.listings l join public.restaurants r on r.id = l.restaurant_id
      where l.id = listing_id and r.owner_user_id = auth.uid()
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.listings l join public.restaurants r on r.id = l.restaurant_id
      where l.id = listing_id and r.owner_user_id = auth.uid()
    )
    or public.is_admin()
  );

-- blocked_categories (public read; admin write)
create policy blocked_read on public.blocked_categories
  for select using (true);
create policy blocked_admin_write on public.blocked_categories
  for all using (public.is_admin()) with check (public.is_admin());

-- orders (state changes ONLY via RPC; no client insert/update policies)
create policy orders_select on public.orders
  for select using (
    buyer_id = auth.uid()
    or public.is_vendor_for_listing(listing_id)
    or public.is_admin()
  );

-- payments (reads only; writes via Edge Functions using service role)
create policy payments_select on public.payments
  for select using (
    exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid())
    or exists (
      select 1 from public.orders o
      where o.id = order_id and public.is_vendor_for_listing(o.listing_id)
    )
    or public.is_admin()
  );

-- payouts (vendor reads own; admin all; writes via service role)
create policy payouts_select on public.payouts
  for select using (
    exists (
      select 1 from public.restaurants r
      where r.id = restaurant_id and r.owner_user_id = auth.uid()
    )
    or public.is_admin()
  );

-- ngos
create policy ngos_select on public.ngos
  for select using (
    verified or contact_user_id = auth.uid() or public.is_admin()
  );
create policy ngos_update_own on public.ngos
  for update using (contact_user_id = auth.uid()) with check (contact_user_id = auth.uid());

-- donations (visibility: vendor of listing, claiming ngo, admin)
create policy donations_select on public.donations
  for select using (
    exists (
      select 1 from public.listings l join public.restaurants r on r.id = l.restaurant_id
      where l.id = listing_id and r.owner_user_id = auth.uid()
    )
    or exists (
      select 1 from public.ngos n where n.id = ngo_id and n.contact_user_id = auth.uid()
    )
    or public.is_admin()
  );

-- ratings (all authenticated can read; inserts via RPC only)
create policy ratings_select on public.ratings
  for select using (auth.uid() is not null or public.is_admin());

-- incidents (buyer sees own; vendor of the order sees; admin all)
create policy incidents_select on public.incidents
  for select using (
    exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid())
    or exists (
      select 1 from public.orders o
      where o.id = order_id and public.is_vendor_for_listing(o.listing_id)
    )
    or public.is_admin()
  );

-- service-role-only tables: NO policies created (outbox, audit_logs,
-- app_config, notification_templates) — anon/authenticated get nothing.
