# Stage 5 — Vendor Flutter App

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 3

---

## 1. Objective

Build the vendor-facing Android app: the 60-second listing flow, order queue, QR pickup verification, donation tap, stats, and payout view. The **60-second test** (`AGENTS.md` §8) governs every screen. Flows per `doc/02-user-flows.md` §1; QA rules per `doc/09`.

## 2. Prerequisites

- [ ] Stage 3 complete (all vendor RPCs + sweeps exist)
- [ ] **Pending decision resolved:** OTP/SMS provider (`doc/PENDING_DECISIONS.md`) — needed for auth implementation

## 3. Task checklist

### 3.1 Auth & onboarding
- [ ] Phone OTP signup/login (chosen provider)
- [ ] Restaurant registration wizard: profile, cuisine tags, map pin, hours, food type, FSSAI number (format-validated), optional GSTIN/PAN, outlet photos
- [ ] Payout details form (bank/UPI ID)
- [ ] SOP agreement screen (must accept to submit)
- [ ] Status screen: PENDING → VERIFIED / rejected+reason (poll or realtime)

### 3.2 Listing creation (the 60-second flow)
- [ ] "Create Box": category chips (Veg/Non-Veg/Egg/Jain) → qty stepper → contents hint text → original value with **auto-suggested price** (40–60% off slider, ₹49 floor enforced live) → pickup window pre-filled from closing time (editable + grace) → **in-app camera capture only** (gallery blocked) → prep/consume-by auto-stamps
- [ ] Photo upload via Edge Function (`upload-listing-photo`): EXIF taken ≤ 15 min, geotag ≤ 500 m — friendly error if violated
- [ ] Publish → live; feed confirmation with countdown
- [ ] Edit qty up/down (never below sold), Sold Out button
- [ ] Blocked-category prevention surfaced clearly (e.g., cut fruit selected → blocked per `doc/09`)

### 3.3 Order management
- [ ] Live order queue (realtime): #id, buyer first name, prepaid ✓/COD, countdown to window end
- [ ] **QR scan** (`mobile_scanner`) → confirm pickup; fallback 6-digit OTP entry
- [ ] COD: mark cash collected (ledger view of today's COD total)
- [ ] Donate leftover (one tap) at/after window close
- [ ] End-of-day summary: sold/donated/wasted, revenue, meals-rescued impact card (screenshot-shareable)

### 3.4 Stats & payouts
- [ ] Daily/weekly stats view (sold, sell-through, wasted, donated)
- [ ] Payout history list (weekly batches, status)
- [ ] 17:30 IST listing nudge display hooks (local notification, consumer for FCM arrives Stage 7)

### 3.5 Quality gates
- [ ] `flutter analyze` + `flutter test` green; new widget tests for listing form (floor enforcement, defaults)
- [ ] All write operations go through RPCs (no direct table writes)
- [ ] Copy check: no "leftover" wording anywhere; "Cooked today, for today" framing on empty states

## 4. Deliverables

- `apps/vendor/` complete app (auth → register → list → orders → donate → stats)
- Screens inventory + APK debug build

## 5. Acceptance criteria

1. Full vendor journey demo on emulator: signup → seeded admin approves in console → create live box in **under 60 seconds** (AI records the walkthrough).
2. Gallery photo rejected; live-camera photo accepted; EXIF validation errors surfaced friendly.
3. Scanning the buyer QR (from seed) marks order `picked_up`; audit row visible in console.
4. Donate tap flips listing to `donated` + donation row created.
5. 60-second test passed on three consecutive attempts.

## 6. Founder manual steps

- Resolve OTP provider decision (before auth build).
- Install app on a physical Android phone (APK side-load) for the 60-second test.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | none yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 3 + OTP decision.
