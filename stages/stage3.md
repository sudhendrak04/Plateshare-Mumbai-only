# Stage 3 — Business Logic (RPCs, Sweeps, Seed, SQL Tests)

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 1 (logic part) + Phase 5 (sweep RPCs only)

---

## 1. Objective

Implement all server-trusted business logic as Postgres RPC functions: the order state machine, atomic inventory, COD gating, ratings, donations, and the three sweep functions. This stage contains the 🔴 money-path SQL (`reserve_order`, `confirm_pickup`) — **tests are written first and must pass before the stage is marked done** (`AGENTS.md` §7).

## 2. Prerequisites

- [ ] Stage 2 complete (`supabase db reset` green, RLS live)

## 3. Task checklist

### 3.1 Buyer RPCs (`0009_rpc_buyer.sql`)
- [ ] 🔴 `reserve_order(listing_id, pay_method)` — FOR UPDATE lock → guarded decrement → create `reserved` order + `expires_at` (10 min) → COD gate (trust ≥ `app_config.cod_threshold`, ≥ `cod_min_orders` prior orders) → audit + outbox rows → returns order_id / razorpay handle
- [ ] `cancel_order(order_id)` — only while `reserved`; releases qty; audit
- [ ] `rate_order(order_id, stars, tags, comment)` — only `picked_up`, one per order
- [ ] `report_incident(order_id, type, evidence_url)` — opens incident + outbox
- [ ] `nearby_listings(lat, lng, radius_m, category, max_price_paise)` — PostGIS ST_DWithin + filters + order by `closes_at`

### 3.2 Vendor RPCs (`0010_rpc_vendor.sql`)
- [ ] `register_restaurant(...)` — status pending; FSSAI format validation
- [ ] `create_listing(...)` — server re-validation: verified vendor + valid FSSAI, price floor/ceiling, consume_by > prep_time, photo present, window defaults from close_time, category not in `blocked_categories`
- [ ] `update_listing_qty`, `mark_sold_out`
- [ ] 🔴 `confirm_pickup(qr_token | otp)` — validate token/expiry/window + order status → `picked_up` (+ `cod_collected` for COD) → audit + outbox (rating nudge, payout line)
- [ ] `donate_leftover(listing_id)` — expired → `donation` row + broadcast outbox
- [ ] `vendor_stats`, `vendor_payouts`

### 3.3 NGO + Admin RPCs (`0011_rpc_ngo_admin.sql`)
- [ ] `ngo_apply`, `ngo_open_donations`, 🔴 `claim_donation` (atomic + `claim_expires_at`), `confirm_donation_pickup`, `report_beneficiaries`
- [ ] `admin_verify_vendor`, `admin_verify_ngo`, `admin_resolve_incident` (refund via outbox), `admin_ops_dashboard`, `admin_gst_ledger`
- [ ] Admin RPCs verify caller `role='admin'` (never trust client)

### 3.4 Sweeps (`0012_rpc_sweeps.sql`) — idempotent, callable by cron in Stage 7
- [ ] `sweep_holds()` — expired reserved orders → release qty → `cancelled`
- [ ] `sweep_listings()` — past window+grace → `expired`; unpaid/unpicked orders → `no_show` + buyer strike (no_show_count++, trust −20) + outbox
- [ ] `sweep_donation_ttl()` — unclaimed/uncollected donations → re-broadcast once → `wasted`
- [ ] `cron_sweep()` — wrapper calling all three

### 3.5 Full seed refresh
- [ ] `0013_seed.sql` complete: demo listing mid-window, orders in every state, an incident, a donation — enough to demo every screen in Stages 4–6

### 3.6 Tests (write FIRST for 🔴 paths)
- [ ] pgTAP: reserve decrements atomically; **last box cannot be oversold** (concurrent simulation); hold expiry releases qty; no-show strike increments + COD gate flips; rating unique per order; claim_donation single-winner; payout math reconciles to the paisa (when Stage 7 lands, same test reused)
- [ ] Smoke script `supabase/tests/smoke.sql`: list → reserve → confirm → rate end-to-end

## 4. Deliverables

- `supabase/migrations/0009…0013`
- `supabase/tests/*.sql` (pgTAP + smoke)
- Updated `backend/backend_plan.md` §3 (checklist → implemented ✓)

## 5. Acceptance criteria

1. All pgTAP tests pass (`supabase db reset && supabase test db` or equivalent run shown).
2. Smoke test passes end-to-end in SQL.
3. Oversell attempt demonstrated failing (two concurrent reserves on qty_left=1 → exactly one succeeds).
4. Every RPC writes `audit_logs` rows (shown in a query walkthrough).
5. COD gate demonstrated: low-trust buyer blocked, eligible buyer allowed.

## 6. Founder manual steps

- None beyond reviewing the demo walkthrough AI provides.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | none yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 2.
