-- Stage 2 · 0003_listings (listings, pickup_windows, blocked_categories) — doc/03 §2
create table public.listings (
  id                   uuid primary key default extensions.gen_random_uuid(),
  restaurant_id        uuid not null references public.restaurants (id),
  category             public.listing_category not null,
  qty_total            int not null check (qty_total > 0),
  qty_left             int not null default 0 check (qty_left >= 0),
  original_value_paise int not null check (original_value_paise > 0),
  price_paise          int not null check (price_paise >= 4900 and price_paise * 2 <= original_value_paise),
  contents_hint        text,
  photo_url            text,
  photo_geo            extensions.geography (Point, 4326),
  photo_taken_at       timestamptz,
  prep_time            timestamptz not null,
  consume_by           timestamptz not null check (consume_by > prep_time),
  closes_at            timestamptz not null,
  status               public.listing_status not null default 'draft',
  donated_at           timestamptz,
  wasted_at            timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint qty_left_lte_total check (qty_left <= qty_total)
);

create index listings_status_closes_idx on public.listings (status, closes_at);
create index listings_restaurant_idx on public.listings (restaurant_id);

create table public.pickup_windows (
  id         uuid primary key default extensions.gen_random_uuid(),
  listing_id uuid not null unique references public.listings (id) on delete cascade,
  start_at   timestamptz not null,
  end_at     timestamptz not null check (end_at > start_at),
  grace_min  int not null default 10 check (grace_min >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.blocked_categories (
  id         uuid primary key default extensions.gen_random_uuid(),
  pattern    text not null unique,
  reason     text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);
