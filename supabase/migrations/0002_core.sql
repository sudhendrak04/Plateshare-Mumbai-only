-- Stage 2 · 0002_core (profiles, clusters, restaurants) — doc/03 §2
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  phone         text unique,
  name          text,
  role          public.user_role not null default 'buyer',
  diet_pref     public.diet_pref not null default 'veg',
  trust_score   int not null default 50 check (trust_score between 0 and 100),
  no_show_count int not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.clusters (
  id        uuid primary key default extensions.gen_random_uuid(),
  name      text not null unique,
  center    extensions.geography (Point, 4326) not null,
  radius_m  int not null default 2000 check (radius_m > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.restaurants (
  id               uuid primary key default extensions.gen_random_uuid(),
  owner_user_id    uuid not null references public.profiles (id),
  name             text not null,
  cuisine_tags     text[] not null default '{}',
  fssai_license    text not null unique check (fssai_license ~ '^[0-9]{14}$'),
  fssai_expiry_date date,
  gstin            text check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{6}$'),
  address          text,
  geo              extensions.geography (Point, 4326),
  open_time        time not null default '10:00',
  close_time       time not null default '22:00',
  food_type        public.food_type not null default 'veg_nonveg',
  status           public.restaurant_status not null default 'pending',
  rating_avg       numeric(3, 2) not null default 0 check (rating_avg between 0 and 5),
  payout_upi       text,
  bank_details     jsonb,
  payout_verified  boolean not null default false,
  suspended_until  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index restaurants_geo_idx on public.restaurants using gist (geo);
create index restaurants_status_idx on public.restaurants (status);
