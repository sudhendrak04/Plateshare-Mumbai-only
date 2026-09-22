# Stage 2 — Database Core (Schema, Constraints, RLS, Triggers)

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 1 (schema part)

---

## 1. Objective

Build the complete, production-shaped database: every table, enum, constraint, index, PostGIS geography, Row-Level-Security policy, and trigger from `doc/03-data-model.md`. After this stage the database exists and enforces its own integrity — even with no app connected.

## 2. Prerequisites

- [ ] Stage 1 complete (Supabase CLI initialized)
- [ ] Supabase project reachable (free tier OK; note: free tier has no pg_cron — irrelevant for this stage)

## 3. Task checklist

### 3.1 Foundations
- [ ] `0000_extensions.sql` — postgis, pgcrypto, moddatetime
- [ ] `0001_enums.sql` — all enums per `backend/backend_plan.md` §5

### 3.2 Tables (in dependency order)
- [ ] `0002_core.sql` — `profiles` (+ auth.users trigger), `clusters`, `restaurants`
- [ ] `0003_listings.sql` — `listings`, `pickup_windows`, `blocked_categories`
- [ ] `0004_orders.sql` — `orders`, `payments`, `payouts`
- [ ] `0005_social.sql` — `ngos`, `donations`, `ratings`, `incidents`
- [ ] `0006_infra.sql` — `outbox`, `audit_logs` (append-only enforced), `app_config`, `notification_templates`

### 3.3 Constraints & indexes (inside the above migrations)
- [ ] Money: integer paise columns only; CHECK `price_paise >= 4900`, `price_paise * 2 <= original_value_paise`
- [ ] Freshness: CHECK `consume_by > prep_time`; listing cannot be live without photo + stamps
- [ ] Inventory: `qty_left` guarded by RPCs (Stage 3) — column + default present now
- [ ] Geo: PostGIS `geography(Point,4326)` on `restaurants`, `clusters`, `ngos` + GIST indexes
- [ ] Uniqueness: unique(order_id) on ratings; unique(razorpay_payment_id) on payments; unique(dedupe_key) on outbox; unique(restaurant_id, period_start) on payouts
- [ ] Performance indexes: `(status, closes_at)` on listings; `(status)` on orders; index on outbox `(status, next_retry_at)`

### 3.4 RLS
- [ ] `0007_rls.sql` — enable RLS on **every** table; policies per `backend/backend_plan.md` §6 matrix
- [ ] `outbox`, `audit_logs`, `app_config` → no client policies at all (service-role only)
- [ ] Helper: `auth_role()` / `current_profile()` functions for policy predicates

### 3.5 Triggers
- [ ] `0008_triggers.sql` — auth.users → profiles auto-create; ratings insert → recompute `restaurants.rating_avg`; updated_at auto-touch where needed

### 3.6 Seed & verification
- [ ] `0013_seed.sql` (written now, refined in Stage 3): 2 Mumbai clusters (Andheri West, Vile Parle), 5 fake verified restaurants, 1 fake admin, test buyers, 1 fake verified NGO
- [ ] `supabase db reset` runs all migrations + seed cleanly from zero

### 3.7 SQL tests (schema-level)
- [ ] pgTAP tests: CHECK constraints reject bad prices; live-without-photo rejected; append-only audit enforced; RLS denies anonymous access to protected tables

## 4. Deliverables

- `supabase/migrations/0000…0013` (schema subset; RPC files come in Stage 3)
- `supabase/seed.sql`
- `supabase/tests/*.sql` (pgTAP)

## 5. Acceptance criteria

1. `supabase db reset` completes without errors from an empty state.
2. AI runs a SQL walkthrough: insert valid seed data → succeeds; attempt oversell-style direct update, bad price, live listing without photo → **all rejected by the DB**.
3. RLS demonstrated: anonymous/anon-key queries against protected tables return empty/denied; authenticated buyer sees only permitted rows.
4. `audit_logs` receives a row for each seeded state change.
5. Founder can open Supabase Table Editor and see all 15 tables with data.

## 6. Founder manual steps

- Provide Supabase project URL + anon key + service-role key (stored locally, never committed).
- (Optional) Quick visual check of tables in Supabase dashboard.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | none yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 1.
