-- Stage 2 · 0004_orders (orders, payments, payouts) — doc/03 §2
create table public.orders (
  id             uuid primary key default extensions.gen_random_uuid(),
  buyer_id       uuid not null references public.profiles (id),
  listing_id     uuid not null references public.listings (id),
  qty            int not null default 1 check (qty > 0),
  amount_paise   int not null check (amount_paise > 0),
  pay_method     public.pay_method not null,
  status         public.order_status not null default 'reserved',
  qr_token       text unique,
  pickup_otp     text,
  expires_at     timestamptz,
  reserved_at    timestamptz not null default now(),
  paid_at        timestamptz,
  picked_up_at   timestamptz,
  cod_collected  boolean not null default false,
  strike_applied boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index orders_status_idx on public.orders (status);
create index orders_listing_idx on public.orders (listing_id);
create index orders_buyer_idx on public.orders (buyer_id);

create table public.payments (
  id                  uuid primary key default extensions.gen_random_uuid(),
  order_id            uuid not null references public.orders (id),
  gateway_ref         text,
  razorpay_order_id   text,
  razorpay_payment_id text unique,
  method              text not null,
  amount_paise        int not null check (amount_paise > 0),
  platform_fee_paise  int not null default 0 check (platform_fee_paise >= 0),
  gst_collected_paise int not null default 0 check (gst_collected_paise >= 0),
  status              public.payment_status not null default 'created',
  refund_ref          text,
  idempotency_key     text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index payments_order_idx on public.payments (order_id);

create table public.payouts (
  id                  uuid primary key default extensions.gen_random_uuid(),
  restaurant_id       uuid not null references public.restaurants (id),
  period_start        date not null,
  period_end          date not null check (period_end >= period_start),
  gross_paise         int not null default 0 check (gross_paise >= 0),
  commission_paise    int not null default 0 check (commission_paise >= 0),
  cod_commission_paise int not null default 0 check (cod_commission_paise >= 0),
  gst_paise           int not null default 0 check (gst_paise >= 0),
  net_paise           int not null default 0 check (net_paise >= 0),
  status              public.payout_status not null default 'pending',
  batch_ref           text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (restaurant_id, period_start)
);

create index payouts_restaurant_idx on public.payouts (restaurant_id);
