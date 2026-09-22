-- Stage 2 · 0005_social (ngos, donations, ratings, incidents) — doc/03 §2
create table public.ngos (
  id              uuid primary key default extensions.gen_random_uuid(),
  contact_user_id uuid not null references public.profiles (id),
  name            text not null,
  reg_12a         text,
  reg_80g         text,
  darpan_id       text,
  geo             extensions.geography (Point, 4326),
  verified        boolean not null default false,
  verified_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index ngos_geo_idx on public.ngos using gist (geo);

create table public.donations (
  id                uuid primary key default extensions.gen_random_uuid(),
  listing_id        uuid not null unique references public.listings (id),
  ngo_id            uuid references public.ngos (id),
  claimed_at        timestamptz,
  picked_up_at      timestamptz,
  claim_expires_at  timestamptz,
  beneficiary_count int check (beneficiary_count is null or beneficiary_count >= 0),
  receipt_no        text unique,
  broadcast_count   int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table public.ratings (
  id         uuid primary key default extensions.gen_random_uuid(),
  order_id   uuid not null unique references public.orders (id),
  stars      int not null check (stars between 1 and 5),
  tags       text[] not null default '{}',
  comment    text,
  created_at timestamptz not null default now()
);

create index ratings_order_idx on public.ratings (order_id);

create table public.incidents (
  id               uuid primary key default extensions.gen_random_uuid(),
  order_id         uuid not null references public.orders (id),
  type             public.incident_type not null,
  evidence_url     text,
  status           public.incident_status not null default 'open',
  resolution_note  text,
  resolved_by      uuid references public.profiles (id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index incidents_status_idx on public.incidents (status);
