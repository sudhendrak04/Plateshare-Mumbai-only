-- Stage 2 · 0006_infra (outbox, audit_logs, app_config, notification_templates) — doc/03 §2
create table public.outbox (
  id            uuid primary key default extensions.gen_random_uuid(),
  channel       text not null check (channel in ('push', 'sms', 'whatsapp', 'razorpay', 'refund')),
  template_key  text not null,
  payload       jsonb not null,
  dedupe_key    text unique,
  status        public.outbox_status not null default 'pending',
  attempts      int not null default 0 check (attempts >= 0),
  next_retry_at timestamptz not null default now(),
  last_error    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index outbox_drain_idx on public.outbox (status, next_retry_at);

create table public.audit_logs (
  id          uuid primary key default extensions.gen_random_uuid(),
  actor_id    uuid,
  actor_role  text,
  entity      text not null,
  entity_id   text,
  action      text not null,
  old_value   jsonb,
  new_value   jsonb,
  created_at  timestamptz not null default now()
);

create index audit_logs_entity_idx on public.audit_logs (entity, entity_id, created_at);

create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

create table public.notification_templates (
  key        text primary key,
  channels   text[] not null default '{push}',
  body       text not null,
  variables  text[] not null default '{}',
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);
