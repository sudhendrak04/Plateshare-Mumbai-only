# Stage 7 — Edge Functions, Scheduled Jobs & Notifications

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 5 (remaining), Phase 6 groundwork

---

## 1. Objective

Wire the "always-on" backend: all Edge Functions (`backend/backend_plan.md` §7), the four scheduled jobs, the outbox worker, and the notification pipeline (FCM + SMS + WhatsApp hooks). By the end, listings expire themselves, no-shows strike automatically, donations broadcast and expire, and every notification trigger in `doc/08` fires in staging.

## 2. Prerequisites

- [ ] Stage 3 complete (sweep RPCs exist)
- [ ] Stages 5–6 apps available for integration testing
- [ ] Razorpay test keys; FCM project; SMS provider decision resolved

## 3. Task checklist

### 3.1 Core Edge Functions (Deno TS)
- [ ] 🔴 `razorpay-create-order` — create gateway order, persist `razorpay_order_id`
- [ ] 🔴 `razorpay-webhook` — HMAC verify first; idempotent on `razorpay_payment_id`; `payment.captured` → order paid; `refund.processed` → refunded; replay test included
- [ ] 🔴 `razorpay-refund` — initiate refund, write `refund_ref`
- [ ] 🔴 `run-payout-batch` — aggregate picked_up per vendor per week → `payouts` rows → payout transfer (mechanism per pending decision) → reconcile to the paisa
- [ ] `upload-listing-photo` — EXIF/geotag validation → storage
- [ ] `send-notification` — outbox drain; FCM / SMS / WhatsApp channels; per-user budget + quiet hours enforced
- [ ] `donation-broadcast` — fan-out to NGOs within 5 km
- [ ] `process-outbox` — generic worker: pending → sent/failed → retry w/ backoff → dead

### 3.2 Scheduled jobs (Supabase Cron → Edge Fns)
- [ ] `sweep-every-minute` → `cron-sweep` (holds, listings, donation TTL)
- [ ] `outbox-every-minute` → `process-outbox`
- [ ] `payout-weekly` (Mon 02:00 IST) → `run-payout-batch`
- [ ] `digest-daily` (18:30 IST) → vendor WhatsApp digest + admin summary
- [ ] Fallback documented: GitHub Actions scheduled workflow hitting sweep endpoint (free-tier cron caveat)

### 3.3 Notifications (per `doc/08`)
- [ ] `notification_templates` seeded with N1–N14 copy
- [ ] FCM integration both apps; deep links (N1→listing, N2/N4/N5→order QR, N8→vendor queue, N10→NGO claims)
- [ ] Anti-fatigue: 4 pushes/day budget, 1/hr throttle on N1, quiet hours 23:30–09:00 IST, SMS only for OTP/N4/N5/N7
- [ ] `notifications_log` written on every send

### 3.4 Vendor payout wiring
- [ ] Implement chosen payout mechanism (per pending decision; default: platform-collect + RazorpayX weekly NEFT)
- [ ] COD commission ledger (`cod_commission_due`) recovery from next prepaid batch

### 3.5 Quality gates
- [ ] Deno tests: webhook signature fail → 401; replayed webhook → single credit; refund idempotency
- [ ] Staging E2E: live box expires → wasted; donated box → broadcast → claim TTL → re-broadcast → wasted
- [ ] Full notification walkthrough: trigger each of N1–N14 in staging, verify copy + channel + log

## 4. Deliverables

- `supabase/functions/*` complete (7 functions + shared utils)
- Cron schedule config; fallback script in `.github/workflows/`
- Notification template seeds; deep-link routing in both apps

## 5. Acceptance criteria

1. Webhook replay test passes (double-send → one credit).
2. Time-travel demo: seed a listing near window end → watch it expire → no-show strike applied → buyer notified. All automatic.
3. Donation TTL demo: broadcast → no claim → 30 min → re-broadcast → still none → `wasted`.
4. Payout batch demo (staging numbers): gross − commission − fees = net reconciles exactly; batch row created.
5. All 14 notification triggers verified with correct channel + quiet-hour behavior.

## 6. Founder manual steps

- FCM project setup (AI gives click-by-click), service account JSON into Supabase secrets.
- SMS provider keys into Supabase secrets (after decision).
- RazorpayX account (if NEFT path) setup.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | Payout mechanism choice lands here (from PENDING_DECISIONS) | Route vs platform-collect NEFT | Founder | pending |
| — | none else yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 3 (sweeps) + payout decision.
