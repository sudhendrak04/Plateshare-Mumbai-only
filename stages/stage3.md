# Stage 3 — Business Logic (RPCs, Sweeps, Seed, SQL Tests)

> **Status:** ✅ Complete
> **Started:** Sep 2026 · **Completed:** Sep 2026
> **Implements:** `doc/12-ai-dev-guide.md` Phase 1 (logic part) + Phase 5 (sweep RPCs)

---

## 1. Objective

Implement all server-trusted business logic as Postgres RPC functions: the order state machine, atomic inventory, COD gating, ratings, donations, and the three sweep functions. This stage contains the 🔴 money-path SQL (`reserve_order`, `confirm_pickup`) — **tests were written alongside and all pass before stage completion** (`AGENTS.md` §7).

## 2. Prerequisites

- [x] Stage 2 complete (`supabase db reset` green, RLS live)

## 3. Task checklist

### 3.1 Buyer RPCs (`0009_rpc_buyer.sql`)
- [x] Shared helpers: `audit()`, `notify()` (outbox), `cfg_int/cfg_date` (app_config readers), `cod_eligible()`
- [x] 🔴 `reserve_order(listing_id, pay_method)` — FOR UPDATE lock → guarded decrement → reserved order + hold (`expires_at`: 10 min prepaid / window−15min COD) → COD gate → QR token + OTP generation → audit (+ N8 vendor notify for COD)
- [x] `cancel_order(order_id)` — reserved-only; releases qty; revives sold_out listing if qty returns
- [x] `rate_order(order_id, stars, tags, comment)` — picked_up-only, one per order (unique violation → `ALREADY_RATED`)
- [x] `report_incident(order_id, type, evidence_url)` — opens incident + audit
- [x] `nearby_listings(lat, lng, radius_m, category, max_price)` — PostGIS ST_DWithin, verified vendors only, ordered by closes_at; returns freshness stamps + window + distance

### 3.2 Vendor RPCs (`0010_rpc_vendor.sql`)
- [x] `register_restaurant(...)` — FSSAI format validation, one-outlet-per-owner, status pending
- [x] 🔴 `create_listing(...)` — server re-validates: verified + non-suspended vendor, FSSAI expiry, ₹49 floor, ≤50% discount, freshness order, photo fields present, window validity, **blocked_categories contents_hint match** → live listing + window (+ defaults from `grace_default_min`)
- [x] `update_listing_qty(listing_id, new_qty_total)` — never below already-sold; auto-revives sold_out
- [x] `mark_sold_out(listing_id)`
- [x] 🔴 `confirm_pickup(order_id, qr_token | otp)` — owner check, QR/OTP match, window+grace check, prepaid requires `paid`, COD requires `reserved` → `picked_up` + `cod_collected`; audit
- [x] `donate_leftover(listing_id)` — expired/past-window only; qty must remain; listing → `donated`; donation row + N10 broadcast (push + WhatsApp) outbox rows
- [x] `vendor_stats(from, to)` — listed/sold/donated/wasted/revenue jsonb
- [x] `vendor_payouts()` — own payout batches

### 3.3 NGO + Admin RPCs (`0011_rpc_ngo_admin.sql`)
- [x] `ngo_apply`, `ngo_open_donations` (≤5 km verified), 🔴 `claim_donation` (atomic single-winner + 30-min `claim_expires_at`), `confirm_donation_pickup`, `report_beneficiaries`
- [x] `admin_verify_vendor` (approve/reject + N14 notify), `admin_verify_ngo`
- [x] `admin_resolve_incident` — refund (order+payment → refunded, razorpay outbox request) / warning / delist7 / delist30 (suspended_until + live listings expired) / ban / dismiss — full suspension ladder
- [x] `admin_ops_dashboard(day)` — per-cluster listed/sold/donated/wasted, **sell-through %**, GMV
- [x] `admin_gst_ledger(month)` — model-agnostic GST export (uses `gst_collected_paise` per payment)
- [x] All admin RPCs verify `is_admin()` server-side (never trusts client)

### 3.4 Sweeps (`0012_rpc_sweeps.sql`) — idempotent, cron-ready
- [x] `sweep_holds()` — expired reserved orders → cancelled + qty restored + sold_out revived
- [x] `sweep_listings()` — past window+grace → expired; unpicked reserved/paid orders → `no_show` + strike (`no_show_count++`, trust −20 floored at 0) + N6 buyer push + audit
- [x] `sweep_donation_ttl()` — stale claims released → re-broadcast once (broadcast_count guard) → listing `wasted`
- [x] `cron_sweep()` — wrapper returning summary jsonb; **execute granted to `service_role` only** (revoked from public/anon/authenticated)

### 3.5 Seed refresh (`supabase/seed.sql`)
- [x] Orders in every state: reserved (test-created), paid, picked_up (×3), no_show, cancelled, refunded
- [x] COD-eligible buyer 022 (trust 80, 2 historical picked_up COD orders + payments)
- [x] Ratings (rating_avg = 4.50 for Andheri Bakery House via trigger), open + resolved incidents
- [x] Completed donation (beneficiary trail + receipt `PS-DON-2026-0001`) + unclaimed donation (NGO-portal demo)

### 3.6 Tests — written per money path (`supabase/tests/rpc.test.sql`, 25 pgTAP assertions)
- [x] reserve decrements atomically; order row + QR/OTP created
- [x] **Last box oversell rejected** (guarded UPDATE, second reserve throws `QTY_EXHAUSTED`)
- [x] Hold expiry → `sweep_holds()` releases qty, cancels orders
- [x] COD gate: low-trust blocked; eligible buyer passes
- [x] No-show sweep: strike increments, trust −20, order `no_show`
- [x] Rating rules: picked_up-only, unique per order
- [x] Donation claim: single winner + pickup confirm + beneficiaries
- [x] Smoke: reserve → simulated payment → QR confirm → rate → `rating_avg` recomputed

## 4. Deliverables

- `supabase/migrations/0009…0012`
- `supabase/tests/rpc.test.sql` (25 assertions)
- Extended `supabase/seed.sql`

## 5. Acceptance criteria

1. ✅ All pgTAP tests pass: **`supabase test db` → Files=2, Tests=35, Result: PASS** (10 schema + 25 RPC).
2. ✅ Smoke test passes end-to-end in SQL (tests 22–25).
3. ✅ Oversell attempt demonstrated failing (test 6: second reserve on qty_left=1 → rejected).
4. ✅ Every RPC writes `audit_logs` (verified: reserved/picked_up/no_show/donated/cancelled actions present).
5. ✅ COD gate demonstrated (tests 9–10): trust-50 buyer blocked, trust-80 buyer allowed.
6. ✅ Buyer cannot flip order status directly — RLS UPDATE policy absent (`UPDATE 0`).

## 6. Founder manual steps

- None this stage.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| 1 | `reserve_order` returns qr_token + pickup_otp (superset of doc/05 return spec) | 3 fields per doc vs 5 fields | AI (trivial superset — buyer UI needs QR+OTP to display) | Sep 2026 |
| 2 | COD hold expiry = window_end − 15 min (doc/07 §1.2 abuse guard implemented in sweep) | 10-min hold for both vs window-relative COD hold | AI (doc-covered) | Sep 2026 |
| 3 | No payment/Razorpay calls inside RPCs — refund/payout requests go through `outbox` rows (outbox pattern per `doc/13-backend-plan.md` §2) | direct gateway calls vs outbox | AI (doc-covered architecture rule) | Sep 2026 |
| 4 | `update_listing_qty` takes absolute `new_qty_total` (not delta) | delta vs set-total | AI (simpler guard math, same UX) | Sep 2026 |
| 5 | Refund execution deferred to Stage 7 webhook; `admin_resolve_incident(refund)` flips rows + enqueues `refund_request` outbox row | full gateway flow now vs staged | AI (per plan §7) | Sep 2026 |

## 8. Status & dates

- Planning: done.
- Execution: done Sep 2026. 25 RPC assertions + 10 schema assertions, all passing.
- Deferred to Stage 7: payout batch SQL (`run_payout_batch`), webhook status flips, real gateway refunds (outbox rows already produced).
- Blockers: none. Stage 4 (admin console) can start.
