# Stage 6 — Buyer Flutter App

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 4

---

## 1. Objective

Build the buyer-facing Android app: discovery (map + list), filtering (veg/non-veg/egg/Jain, distance, price), reservation, payment (test-mode Razorpay + COD per trust), QR pickup, rating, and report-a-problem. Flows per `doc/02-user-flows.md` §2; notification UX per `doc/08`; freshness disclosures per `doc/09` §3.

## 2. Prerequisites

- [ ] Stage 3 complete (buyer RPCs, COD gate)
- [ ] Stage 5 complete (vendor app can create live boxes for realistic testing)
- [ ] OTP provider decision resolved
- [ ] Razorpay **test** keys obtained (founder manual step)

## 3. Task checklist

### 3.1 Auth & profile
- [ ] Phone OTP signup/login; optional name
- [ ] Diet preference onboarding (Veg default ON); Jain as first-class option
- [ ] Home area set (coarse)

### 3.2 Discovery
- [ ] Home = split view: map (Google Maps, live pins) + card list
- [ ] `nearby_listings` integration: default ≤ 2 km, closing-soonest-first
- [ ] Filters: veg/non-veg/egg/Jain · distance · price · pickup window · cuisine
- [ ] Card content per `doc/02` §2.1: photo, "worth ₹X → ₹Y", window + countdown, prep & consume-by stamps, vendor rating, "N left"
- [ ] Freshness disclosure block on detail + pickup screens (`doc/09` §3 format)

### 3.3 Reserve & pay
- [ ] Reserve → 10-min hold (realtime countdown, auto-cancel on expiry)
- [ ] Razorpay Checkout (test keys), UPI-first instrument ordering
- [ ] Pay-at-Pickup option: visible only if trust gate passes; blocked state explains why
- [ ] Confirmation screen: order ID + QR code + window + directions button
- [ ] Order history with live status (realtime updates)

### 3.4 Pickup & feedback
- [ ] QR screen (large, bright) + 6-digit OTP display as fallback
- [ ] Post-pickup rating: stars + tags (quantity/freshness/value) + comment
- [ ] Report-a-problem: type + mandatory photo → incident opened (refund-first messaging)
- [ ] No-show state explanation screen (strike display: n/3)

### 3.5 Settings & polish
- [ ] Notification preferences screen (per-user budget respected from Stage 7)
- [ ] Terms/privacy screens (DPDP basics: consent, deletion request path)
- [ ] Empty/loading/error states for every screen; no silent failures

### 3.6 Quality gates
- [ ] `flutter analyze` + `flutter test` green; widget tests for filters and price display (paise formatting)
- [ ] All money formatting via one utility (integer paise → ₹ string)
- [ ] Copy check: no "leftover"; freshness stamps always visible

## 4. Deliverables

- `apps/buyer/` complete app (auth → discover → reserve → pay → pickup → rate)
- Debug APK + walkthrough recording

## 5. Acceptance criteria

1. End-to-end demo (test mode): seed vendor box → buyer discovers → reserves → pays (test UPI) → vendor app scans buyer QR → buyer rates. All states flip correctly in console.
2. Veg filter default verified; Jain filter functional.
3. Hold expiry demonstrated: unpaid reservation self-cancels, qty returns.
4. COD gate verified with seeded low-trust and high-trust buyers.
5. Report-a-problem creates incident visible in admin console; refund decision works (test).

## 6. Founder manual steps

- Razorpay account + test keys into local env (AI instructs).
- Physical-device demo optional (same as Stage 5).

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | none yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 5 (needs live boxes) + Razorpay test keys.
