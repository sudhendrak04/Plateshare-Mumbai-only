# Stage 2 — Database Core (Schema, Constraints, RLS, Triggers)

> **Status:** ✅ Complete
> **Started:** Sep 2026 · **Completed:** Sep 2026
> **Implements:** `doc/12-ai-dev-guide.md` Phase 1 (schema part)

---

## 1. Objective

Build the complete, production-shaped database: every table, enum, constraint, index, PostGIS geography, Row-Level-Security policy, and trigger from `doc/03-data-model.md`. After this stage the database exists and enforces its own integrity — even with no app connected.

## 2. Prerequisites

- [x] Stage 1 complete (Supabase CLI initialized)
- [x] Docker Desktop present (engine started for local Supabase stack)

## 3. Task checklist

### 3.1 Foundations
- [x] `0000_extensions.sql` — postgis, pgcrypto, moddatetime
- [x] `0001_enums.sql` — 13 enums

### 3.2 Tables
- [x] `0002_core.sql` — profiles, clusters, restaurants (+ auth.users FK, FSSAI/GSTIN format checks, GIST geo indexes)
- [x] `0003_listings.sql` — listings (price floor + discount ceiling + freshness CHECKs, closes_at denormalized), pickup_windows, blocked_categories
- [x] `0004_orders.sql` — orders (qr_token/otp/hold expiry/COD flags), payments (razorpay refs, gst_collected_paise), payouts (incl. cod_commission_paise, unique per vendor+period)
- [x] `0005_social.sql` — ngos, donations (claim TTL fields, receipt_no), ratings (unique per order), incidents
- [x] `0006_infra.sql` — outbox (dedupe_key, retry fields), audit_logs (append-only), app_config, notification_templates

### 3.3 Constraints & indexes
- [x] Money integer paise; CHECK `price_paise >= 4900`, `price_paise * 2 <= original_value_paise`
- [x] Freshness CHECK `consume_by > prep_time`
- [x] PostGIS geography + GIST (restaurants, clusters, ngos)
- [x] Uniqueness: ratings(order_id), payments(razorpay_payment_id), outbox(dedupe_key), payouts(restaurant_id, period_start), donations(listing_id)
- [x] Performance: listings (status, closes_at); orders (status); outbox (status, next_retry_at)

### 3.4 RLS
- [x] `0007_rls.sql` — RLS enabled on all 17 tables; policies per `doc/13-backend-plan.md` §6
- [x] Helpers: `app_role()`, `is_admin()`, `is_vendor_for_listing(uuid)` (security definer — breaks the orders↔listings policy recursion)
- [x] outbox / audit_logs / app_config / notification_templates → zero client policies (service-role only)

### 3.5 Triggers
- [x] `0008_triggers.sql` — auth.users → profiles (role from server-side app metadata); moddatetime updated_at on 12 tables; **live-listing guard** (photo + EXIF fields + verified vendor required to publish); pickup_window → listings.closes_at sync; ratings → restaurants.rating_avg recompute; audit_logs immutable (update+delete raise)

### 3.6 Seed & verification
- [x] `supabase/seed.sql` — 2 Mumbai clusters (Andheri West, Vile Parle), 5 verified vendors, 3 buyers, 1 admin, 1 verified NGO, 8 config keys, 14 notification templates, 5 blocked categories, demo live listing + window, 7 audit rows
- [x] `supabase db reset` runs cleanly from zero

### 3.7 SQL tests
- [x] `supabase/tests/schema.test.sql` — 10 pgTAP tests, **all passing**

## 4. Deliverables

- `supabase/migrations/0000…0008` (9 migrations)
- `supabase/seed.sql`, `supabase/tests/schema.test.sql`

## 5. Acceptance criteria

1. ✅ `supabase db reset` completes without errors from empty state.
2. ✅ Constraint walkthrough: price below ₹49 floor → rejected; 0%-off price → rejected; consume_by ≤ prep_time → rejected; live-without-photo → rejected (all via pgTAP).
3. ✅ RLS demonstrated: anon sees 0 orders / 0 outbox / 0 audit rows but **can** see the 1 live listing (discovery works); anon INSERT on orders denied; authenticated buyer sees exactly 1 profile row (own).
4. ✅ audit_logs holds 7 seeded rows; update/delete attempts raise `AUDIT_IMMUTABLE`.
5. ✅ 10/10 pgTAP tests pass (`supabase test db` → Result: PASS).

## 6. Founder manual steps

- None this stage. (Supabase hosted project keys still pending — needed by Stage 4/5/6, not by this local stage.)

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| 1 | Seed lives in `supabase/seed.sql` (CLI-native) instead of a `0013_seed.sql` migration | migration vs seed.sql | AI (doc-covered detail) — seed only runs on `db reset`, keeping fake data out of future prod migrations | Sep 2026 |
| 2 | Profile role assigned from `raw_app_meta_data` (server-side) at signup | user-editable metadata vs app metadata | AI (security: app metadata is server-controlled) | Sep 2026 |
| 3 | `is_vendor_for_listing(uuid)` security-definer helper to break RLS recursion | recursive policy fix vs helper fn | AI (standard Postgres pattern) | Sep 2026 |
| 4 | `suspended_until` column added on restaurants (supports admin suspension ladder from `doc/02` §4.1) | deferred to Stage 4 vs now | AI (cheap foresight, schema-only) | Sep 2026 |

## 8. Status & dates

- Planning: done.
- Execution: done Sep 2026. Local Supabase stack running via Docker.
- Blockers: none. Stage 3 can start.
