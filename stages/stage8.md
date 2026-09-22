# Stage 8 — Payments Live (CA-Gated), Hardening & Launch Prep

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phases 6–7

---

## 1. Objective

Take the system from staging to Mumbai-launch readiness: monitoring, the promo engine, production Supabase + live Razorpay keys (only after the CA gate), Play Store release, and the private beta with recruited vendors. This stage ends when the buyer + vendor apps are live in at least one Mumbai cluster.

## 2. Prerequisites

- [ ] Stages 4–7 complete (console, both apps, jobs, notifications all green in staging)
- [ ] 🔴 **CA consult done → GST model chosen** (`doc/07` §4) — hard gate, no live money before this
- [ ] Business entity registered; Razorpay KYC approved; payout mechanism decision executed
- [ ] GST ledger implementation updated to the chosen model (schema already stores `gst_collected_paise` — adjust only if Model B chosen)

## 3. Task checklist

### 3.1 Hardening & monitoring
- [ ] Sentry wired in both Flutter apps + console
- [ ] PostHog funnels: signup → discovery → reserve → pay → pickup → rate
- [ ] Ops runbook doc: common failures + first-response steps for founders

### 3.2 Promo engine (₹49 rescue pack, referral ₹20 credit)
- [ ] `app_config`-driven promos; per-user first-box rule
- [ ] Buyer-side display + validation; audit rows for promo usage

### 3.3 Production environment
- [ ] Supabase prod project (free tier OK for beta; upgrade trigger documented at 500 MB / limits)
- [ ] Migrations + seed-less deploy to prod; admin accounts seeded
- [ ] Razorpay **live** keys in prod secrets only after CA gate
- [ ] Smoke test suite run against prod (with tiny real transaction, then self-refund)

### 3.4 Release
- [ ] Release builds: signed AAB for buyer + vendor (`--dart-define` prod env)
- [ ] Play Store: two app listings (internal testing track first), store listings, privacy policy URL, data-safety form
- [ ] Vendor app distribution: Play internal testing + direct APK fallback for early onboarders

### 3.5 Beta operations (Mumbai)
- [ ] Wave-1 clusters active: Andheri West + Vile Parle seeded in `clusters`
- [ ] Private beta: 10–15 recruited vendors listing real boxes; team + ambassadors buying
- [ ] Sell-through % dashboard monitored daily; target > 50% for public-launch gate (`doc/10` §2)
- [ ] Weekly mystery-shop audits begun (`doc/09` layer 7); incident SOP drill once

### 3.6 Legal/compliance closeout
- [ ] Buyer T&C + vendor agreement finalized (lawyer-reviewed or CA-reviewed)
- [ ] DPDP consent + deletion request path live
- [ ] FSSAI verification SOP doc for admins

## 4. Deliverables

- Production Supabase + live payments (gated)
- Signed release builds + Play Store internal-testing releases
- Runbook + compliance pack (T&C, SOP, privacy)
- Beta live in one cluster with real vendors

## 5. Acceptance criteria

1. Real ₹1–49 test transaction end-to-end on prod with live UPI, then refunded.
2. Sentry captures an intentionally-triggered error (proof monitoring works).
3. Both apps in Play internal testing, installable by founder + first vendors.
4. First 3 real vendor boxes listed and sold via the apps in Mumbai.
5. Sell-through % reported daily from the console dashboard.

## 6. Founder manual steps

| # | Step | Gate |
|---|---|---|
| 1 | CA consult + choose GST model | 🔴 hard gate for live money |
| 2 | Razorpay KYC (needs entity) | gate for live keys |
| 3 | Play Console account ($25) + listings data | release |
| 4 | Vendor recruitment per `doc/10` §3 playbook | beta supply |
| 5 | Physical vendor onboarding sessions (or field person) | beta supply |

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | GST model (A: ECO / B: agent) | per `doc/07` §4 | Founder + CA | pending — hard gate |
| — | Insurance purchase timing | now vs post-revenue | Founder | pending |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stages 4–7 + CA gate.
