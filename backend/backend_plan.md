# Backend Plan — Plate Share (Concise Reference)

> **Status:** Reference plan. Detailed build spec to be expanded later (per founder).
> **Source of truth:** `doc/04-architecture.md` (components), `doc/05-api-spec.md` (endpoints), `doc/03-data-model.md` (schema). This file indexes the backend decisions and cross-references those docs.

---

## 1. What "the backend" is

Plate Share uses **Supabase as the backend** — no custom application server. The backend is seven artifacts:

| # | Artifact | Location | Contents |
|---|---|---|---|
| 1 | Database schema | `supabase/migrations/*.sql` | Tables, enums, constraints, indexes, PostGIS |
| 2 | RLS policies | same migrations | Who can read/write which rows |
| 3 | RPC functions | same migrations | Server-trusted business logic |
| 4 | Edge Functions | `supabase/functions/*` | External-service glue (Razorpay, notifications, photos) |
| 5 | Scheduled jobs | Supabase Cron + `outbox` table | Expiry sweeps, no-show, donation TTL, payouts |
| 6 | Storage + Auth | Supabase dashboard / `config.toml` | Phone OTP, photo buckets |
| 7 | Secrets / env | Supabase dashboard + GitHub secrets | Keys — never in repo |

## 2. Core design rules

1. **The outbox pattern.** Postgres RPCs **never** call external services. Any RPC needing a side effect (push, SMS, Razorpay call) inserts a row into `outbox`. A scheduled Edge Function drains `outbox` with idempotency + retry. Keeps Postgres atomic and gives a free retry queue.
2. **Money is integer paise.** No floats anywhere (per `AGENTS.md` §6).
3. **Timestamps are UTC (`timestamptz`)**; IST only at render.
4. **Every state transition writes `audit_logs`** (append-only).
5. **Atomic inventory** via guarded `UPDATE ... WHERE qty_left > 0` — never read-then-write.
6. **Webhooks verify HMAC first**, and are idempotent on `razorpay_payment_id`.
7. **RLS default-deny** on every table.

## 3. Money-paths (🔴 tests mandatory — per `AGENTS.md` §7)

- 🔴 `reserve_order` RPC (hold, atomic decrement, COD gating)
- 🔴 `confirm_pickup` RPC (QR/OTP, window check, COD cash marking)
- 🔴 `razorpay-webhook` Edge Fn (signature + replay-safe, single credit)
- 🔴 `razorpay-refund` Edge Fn
- 🔴 `run-payout-batch` Edge Fn (gross − commission − fees = net, reconcile to the paisa)

## 4. Backend component map

```
Client apps (Flutter) ── Supabase Auth JWT ──> Postgres (RLS + RPCs)
        │                                        │  (state changes → outbox)
        │                                        ▼
        └────────── Edge Functions ◄────── scheduled Cron (sweep/outbox/payout/digest)
                     │     │     │
                  Razorpay  FCM   MSG91/WhatsApp
```

## 5. Schema (index — full fields in `doc/03-data-model.md`)

Extensions: `postgis`, `pgcrypto`, `moddatetime`.
Core tables: `profiles`, `restaurants`, `clusters`, `listings`, `pickup_windows`, `orders`, `payments`, `payouts`, `ngos`, `donations`, `ratings`, `incidents`, `outbox`, `audit_logs`, `app_config`.
Enums: user_role, diet_pref, food_type, restaurant_status, listing_category, listing_status, pay_method, order_status, payment_status, payout_status, incident_type, incident_status, outbox_status.

## 6. RLS policy matrix (summary — full in build spec)

| Table | Buyer | Vendor | NGO | Notes |
|---|---|---|---|---|
| `profiles` | own | own | own | |
| `restaurants` | read `verified` | read/write own | read `verified` | |
| `listings` | read `live` + ordered | read/write own | read `live` | |
| `orders` | own | own listing's | — | status changes via RPC only |
| `payments` | own | own via order | — | inserts via Edge Fn (service role) |
| `ratings` | insert own, read all | read own | — | |
| `donations` | — | write own | claim via RPC | |
| `incidents` | insert own | read own | — | |
| `outbox` / `audit_logs` / `app_config` | — | — | — | **service-role only** |

**Security rule:** admin console never embeds `service_role`. Admin actions call Edge Functions that verify `role='admin'` JWT claim, then use service-role internally.

## 7. Edge Function catalog (index — detail in `doc/05-api-spec.md` §6)

- 🔴 `razorpay-create-order`, `razorpay-webhook`, `razorpay-refund`
- 🔴 `run-payout-batch`
- `upload-listing-photo` (EXIF validation: taken ≤ 15 min, geotag ≤ 500 m, JPEG ≤ 5 MB)
- `send-notification` (FCM / MSG91 / WhatsApp)
- `donation-broadcast` (fan-out to NGOs within 5 km)
- `process-outbox` (generic worker)
- `cron-sweep` (calls `sweep_holds`, `sweep_listings`, `sweep_donation_ttl`)

## 8. Scheduled jobs

| Cron | Schedule | Calls |
|---|---|---|
| sweep | every minute | `cron-sweep` |
| outbox drain | every minute | `process-outbox` |
| payout | Mon 02:00 IST | `run-payout-batch` |
| digest | 18:30 IST | vendor WhatsApp + admin summary |

**Free-tier note:** pg_cron is **not** available on the free plan. Use Supabase scheduled Edge Functions (Cron). Fallback if unavailable: a GitHub Actions scheduled workflow that POSTs to the sweep endpoint. Two per-minute functions ≈ 86k invocations/month (within the 500k free limit).

## 9. Payments (resolved for v1)

- **Prepaid UPI:** `reserve_order` → `razorpay-create-order` → client Checkout → `razorpay-webhook` (`payment.captured`) → order `paid`.
- **COD:** same inventory hold; `confirm_pickup` marks `cod_collected`; commission recovered from next prepaid payout.
- **Payouts:** mechanism = PENDING (see `doc/PENDING_DECISIONS.md`).
- **Refunds:** refund-first policy; `razorpay-refund` → webhook → `refunded`.
- **GST/ECO model:** still the launch blocker — resolve via CA before any live transaction (`doc/07` §4).

## 10. Auth

- Phone OTP via Supabase Auth (identity = phone).
- **Provider = PENDING** (Twilio native vs MSG91 custom hook — see `doc/PENDING_DECISIONS.md`). Free tier only supports native providers (no custom auth hooks).
- Transactional SMS (alerts/refunds) is separate from OTP and routes through an Edge Function directly (MS G91 or Twilio) — unaffected by the pending OTP decision.

## 11. Storage

- Bucket `listing-photos` (private, signed URLs). Upload only via `upload-listing-photo`.

## 12. Configuration

`app_config` keys: `commission` (free-period end, ₹5/box), `cod_threshold` (70), `cod_min_orders` (2), `price_floor_paise` (4900), `max_discount` (0.50), `promo_first_box` (4900), `grace_default_min` (10).

## 13. Secrets

`SUPABASE_SERVICE_ROLE_KEY` (Edge Fns only), `RAZORPAY_KEY_ID/SECRET/WEBHOOK_SECRET`, `RAZORPAYX_*`, `FCM_SERVER_KEY`, `MSG91_AUTH_KEY` + DLT template IDs, `WHATSAPP_*` (v1.1). All in dashboard/Edge-Function secrets — never in repo.

## 14. Migration order (numbered, run in sequence)

1. `extensions.sql`
2. `0001_enums.sql`
3. `0002_tables.sql`
4. `0003_listings_windows.sql`
5. `0004_orders_payments.sql`
6. `0005_ngos_donations_ratings_incidents.sql`
7. `0006_outbox_audit_config.sql`
8. `0007_rls_policies.sql`
9. `0008_triggers.sql`
10. `0009_rpc_buyer.sql`
11. `0010_rpc_vendor.sql`
12. `0011_rpc_ngo_admin.sql`
13. `0012_rpc_sweeps.sql`
14. `0013_seed.sql`

## 15. Testing

- SQL: pgTAP for RPCs — every 🔴 path has a test (oversell guard, hold expiry, no-show strike, payout reconciliation).
- Edge Functions: Deno tests, mocked Razorpay/FCM; webhook replay-idempotency test.
- Daily smoke test script (per `doc/12` §5).

## 16. Environments

`dev` (local Supabase CLI) → `staging` (Razorpay **test** keys) → `prod` (live keys, gated on CA decision).

## 17. Open / pending decisions

See `doc/PENDING_DECISIONS.md`. When resolved, update this file and the build spec.
