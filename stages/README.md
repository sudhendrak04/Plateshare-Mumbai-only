# Stages — Plate Share Build Record

> This folder is the **build journal** of the project. Every stage gets one `.md` file (`stage1.md` … `stage8.md`) that records what is planned, what was built, what was verified, decisions taken, and anything pending — so we always know exactly where the project stands.
>
> Stage division follows the build order in `doc/12-ai-dev-guide.md` §2 (refined into 8 stages). Per `AGENTS.md` §9, any critical/architectural decision arising inside a stage is confirmed with the founder first and logged in that stage's Decision Log.

---

## 1. Stage index & progress

| Stage | File | Scope | Depends on | Status |
|---|---|---|---|---|
| 1 | `stage1.md` | Repo scaffolding + tooling (git, Flutter apps, Supabase project, CI) | — | ✅ Complete |
| 2 | `stage2.md` | Database core — schema, enums, constraints, RLS, triggers | 1 | ✅ Complete |
| 3 | `stage3.md` | Business logic — RPC functions, sweeps, seed, SQL tests | 2 | ✅ Complete |
| 4 | `stage4.md` | Admin + NGO web console (Next.js) | 2 (3 for queues) | ✅ Complete |
| 5 | `stage5.md` | Vendor Flutter app | 3 | ⬜ Not started |
| 6 | `stage6.md` | Buyer Flutter app | 3 | ⬜ Not started |
| 7 | `stage7.md` | Edge Functions, scheduled jobs, notifications | 3 | ⬜ Not started |
| 8 | `stage8.md` | Payments live (CA-gated) + polish + launch prep | 4–7 | ⬜ Not started |

Status values: ⬜ Not started · 🟨 In progress · ✅ Complete · ⛔ Blocked

## 2. Conventions for every stage file

Each `stageN.md` has the same fixed sections:

1. **Objective** — what this stage achieves and why it exists at this point.
2. **Prerequisites** — what must be true before starting.
3. **Task checklist** — granular checkboxes; ticked as work completes (this is the running record).
4. **Deliverables** — exact files/folders/artifacts produced.
5. **Acceptance criteria** — how the founder verifies the stage is done (non-coder-friendly).
6. **Founder manual steps** — accounts to create, keys to obtain, things AI cannot do.
7. **Decision log** — every architectural/important decision taken during the stage, with date and founder approval.
8. **Status & dates** — started / completed timestamps.

Rules:
- A stage is ✅ only when **all** acceptance criteria pass — never before.
- Decisions are logged **at the time they are made**, not retroactively.
- If work is blocked, the blocker is written in the stage file (⛔) with what is needed to unblock.
- Nothing from a later stage gets built early to "save time."

## 3. Stage-to-doc mapping

| Stage | Implements | Key reference docs |
|---|---|---|
| 1 | `doc/12` Phase 0 | `doc/06` (stack), `AGENTS.md` §4 |
| 2 | `doc/12` Phase 1 (schema part) | `doc/03` (data model), `doc/13-backend-plan.md` §5–6 |
| 3 | `doc/12` Phase 1 (logic part) | `doc/05` (API/RPC), `doc/13-backend-plan.md` §3 |
| 4 | `doc/12` Phase 2 | `doc/02` §4 (admin flows), `doc/05` §5 |
| 5 | `doc/12` Phase 3 | `doc/02` §1 (vendor flows), `doc/09` (QA rules) |
| 6 | `doc/12` Phase 4 | `doc/02` §2 (buyer flows), `doc/08` (notifications UX) |
| 7 | `doc/12` Phase 5 | `doc/04` §4 (jobs), `doc/08` (triggers), `doc/13-backend-plan.md` §7–8 |
| 8 | `doc/12` Phases 6–7 | `doc/07` (payments/compliance), `doc/10` (launch) |

## 4. Pending decisions that gate stages

Tracked in `doc/PENDING_DECISIONS.md`:

| Decision | Gates | Resolution deadline |
|---|---|---|
| OTP/SMS provider (Twilio native vs MSG91 hook) | Stage 5/6 auth screens (implementation), Stage 1 (SDK choice) | Before Stage 5 auth build |
| Vendor payout mechanism (platform-collect NEFT vs Route) | Stage 7 payout function, Stage 8 live payouts | After CA consult (Week-4 gate) |
| GST/ECO model (CA consult) | Stage 8 — hard gate before any live money | Week 4 |

## 5. Progress journal (append-only, newest on top)

| Date | Entry |
|---|---|
| Sep 2026 | Stage folder created; 8 stages defined; no build work started yet. |
| Sep 2026 | **Stage 1 complete** — toolchain installed (Flutter 3.47.5, JDK 17, Android SDK 36, Supabase CLI 2.117.0), both Flutter apps + Next.js console scaffolded, all analyze/lint/test/build gates green, debug APKs built for both apps, CI workflow committed, initial git commit. Deferred: emulator/device check (founder), GitHub push (founder), shadcn init (Stage 4). |
| Sep 2026 | **Stage 2 complete** — 9 migrations (17 tables, 13 enums, PostGIS, price/freshness constraints, RLS on all tables, 5 trigger groups incl. live-listing guard + audit immutability), seed data (2 Mumbai clusters, 5 vendors, NGO, demo listing), 10/10 pgTAP tests passing. Fixed RLS recursion via security-definer helper. |
| Sep 2026 | **Stage 3 complete** — 25 RPC functions (buyer/vendor/NGO/admin + 3 sweeps + cron wrapper), COD trust gate, QR/OTP pickup verification, suspension ladder, donation broadcast/claim/TTL, all money-path pgTAP tests passing (35 tests total across both files). Money-path tests written alongside implementation. Seed now demos every order state. Payment gateway + payout SQL deferred to Stage 7 (outbox rows produced). |
| Sep 2026 | **Stage 4 complete** — full Next.js console (admin: ops dashboard w/ sell-through, vendor+NGO verification queues, listing audit with EXIF/geo flags + one-click delist, dispute resolution, GST CSV export; NGO portal with claim/pickup/beneficiaries), live Mumbai-IST clock, role-guarded shell. Security migration 0013: column-level grants kill vendor self-verification escalation, self-escalation trigger, audit RPC raises for non-admins. All gates green (lint/tsc/build 0, 35/35 SQL tests, API smoke incl. NGO-denied-on-admin-RPC). Dev logins seeded. |
| Sep 2026 | Founder walkthrough fixes: NGO role assignment (seed + `ngo_apply` grants `role='ngo'`), `admin_verify_vendor` enum CASE typing + N14 dedupe collision — verify path now pgTAP-covered (40 tests). Console bugs found and fixed by founder-as-tester. |
| Sep 2026 | Docs restructure: `backend/backend_plan.md` moved to `doc/13-backend-plan.md`; `backend/` folder removed; all cross-references updated. |
