# AGENTS.md — Plate Share

Instructions for AI coding agents working in this repository. Read this file fully before making any change. The `doc/` folder is the authoritative specification — when code and docs conflict, the docs win unless the founder explicitly approves a design change (then update the doc in the same commit).

---

## 1. Project context

**Plate Share** is a surplus-food marketplace for Mumbai, India. Restaurants, cafés, and bakeries list unsold food as discounted "mystery boxes" (30–50% off, ₹49 floor) for self-pickup near closing time. Unsold boxes can be donated to verified NGOs. There is **no delivery** — pickup only.

- **Team:** 2 founders with **zero software development experience**. All code is written by AI. The founder gives direction and feedback; the agent is expected to work autonomously but **explain anything the founder must do manually** (running commands, creating accounts, approving PRs) in plain, non-technical language.
- **Status:** Planning complete (`doc/00`–`doc/12`). No application code exists yet. Build order is defined in `doc/12-ai-dev-guide.md` §2 — follow it strictly: **admin console → vendor app → buyer app → jobs/notifications → payments live**.
- **Launch scope:** Mumbai only (Andheri West + Vile Parle clusters first). Do not build multi-city, iOS, delivery, or WhatsApp-bot features unless asked — they are documented as later phases.

## 2. Authoritative documents

| Topic | Doc |
|---|---|
| Scope, non-goals, metrics | `doc/00-overview.md` |
| Market/regulatory research | `doc/01-research.md` |
| User flows & state machines | `doc/02-user-flows.md` |
| Database schema & integrity rules | `doc/03-data-model.md` |
| Architecture & scheduled jobs | `doc/04-architecture.md` |
| API surface | `doc/05-api-spec.md` |
| Tech stack & rejected alternatives | `doc/06-tech-stack.md` |
| Payments, refunds, compliance | `doc/07-payments-compliance.md` |
| Notification triggers & copy | `doc/08-notifications.md` |
| Food-safety QA system | `doc/09-qa-food-safety.md` |
| Launch plan (Mumbai) | `doc/10-launch-plan.md` |
| Risks & kill criteria | `doc/11-risks.md` |
| How to build with AI (order of work, prompts, guardrails) | `doc/12-ai-dev-guide.md` |
| Backend plan reference (outbox pattern, money-paths, RLS matrix) | `doc/13-backend-plan.md` |

## 3. Tech stack (do not substitute)

- **Mobile:** Flutter 3.x (Dart), Android-first. Buyer app and Vendor app are separate Flutter apps under `apps/buyer/` and `apps/vendor/`.
- **Backend:** Supabase — Postgres 15 + PostGIS, Auth (phone OTP via MSG91), Edge Functions (Deno/TypeScript), Realtime, Storage, pg_cron. **No custom API server** (NestJS/FastAPI/Express are rejected — see `doc/06-tech-stack.md` §2). Transactional logic lives in Postgres RPC functions; external-service glue lives in Edge Functions.
- **Web console:** Next.js + Tailwind + shadcn/ui (`console/`), deployed on Vercel.
- **Payments:** Razorpay (Standard PG + Route for vendor payouts). UPI-first. Test keys until the founder explicitly says the CA/legal gate (`doc/07` §4) is cleared.
- **Notifications:** FCM (push), MSG91 (SMS/OTP), WhatsApp Cloud API (v1.1, vendors only).
- **Maps:** Google Maps Flutter plugin.
- **Infra region:** Supabase Mumbai (ap-south-1).

If an agent believes a stack choice is wrong, raise it in the response text — do not silently swap libraries or add infrastructure.

## 4. Target folder structure

```
PlateShare/
├── AGENTS.md               ← this file
├── README.md
├── doc/                    ← specification documents (edit only alongside approved changes)
├── apps/
│   ├── buyer/              Flutter app (buyers)
│   └── vendor/             Flutter app (restaurants)
├── console/                Next.js admin + NGO web console
├── supabase/
│   ├── migrations/         SQL migrations (from doc/03)
│   ├── functions/          Edge Functions (Deno TS)
│   ├── seed.sql            fake vendors/listings for dev
│   └── config.toml
└── .github/workflows/      CI: flutter analyze/test, APK artifact
```

## 5. Commands

Run these from the stated directory. If a scaffold doesn't exist yet, create it per `doc/12-ai-dev-guide.md` before running.

| Task | Directory | Command |
|---|---|---|
| Install Flutter deps | `apps/buyer` or `apps/vendor` | `flutter pub get` |
| Static analysis (must pass) | same | `flutter analyze` |
| Unit/widget tests (must pass) | same | `flutter test` |
| Debug run | same | `flutter run` |
| Release APK | same | `flutter build apk --release` |
| Install web deps | `console` | `npm install` |
| Lint web (must pass) | `console` | `npm run lint` |
| Typecheck web (must pass) | `console` | `npx tsc --noEmit` |
| Build web (must pass) | `console` | `npm run build` |
| Local Supabase stack | `supabase` | `supabase start` |
| Apply migrations | `supabase` | `supabase db reset` |
| Run Edge Functions locally | `supabase` | `supabase functions serve` |

Before declaring any task complete: run the relevant analyze/lint/typecheck/test commands and fix failures. Never leave the repo in a state that fails them.

## 6. Non-negotiable code rules

1. **Money is integer paise.** Never use float/double for any amount (prices, fees, payouts, GST). Field names end in `_paise`. A ₹79 box is `7900`.
2. **Timestamps are UTC (`timestamptz`) everywhere server-side.** IST rendering happens only in the UI layer. India has no DST, but midnight-boundary bugs still exist — test window edges.
3. **Inventory decrements are guarded, atomic SQL:**
   `UPDATE listings SET qty_left = qty_left - 1 WHERE id = $1 AND qty_left > 0;`
   then check affected rows. Never read-then-write. Never decrement in application code.
4. **Server-side re-validation of everything the client sends:** price floor (≥ ₹49 = `4900` paise), discount ceiling (price ≤ 50% of original value), `consume_by > prep_time`, photo presence, FSSAI validity. RLS policies + RPC guards, not just app-side checks.
5. **Every state transition writes to `audit_logs`** (append-only). Orders and payments are never deleted or mutated destructively — corrections are new rows.
6. **State machines are exactly as defined in `doc/02-user-flows.md` §5.** No ad-hoc statuses.
7. **No secrets in code.** Razorpay keys, service-role keys, MSG91 keys go in environment variables / Supabase dashboard / GitHub encrypted secrets. If generated code contains any credential, remove it and flag it.
8. **Webhook handlers verify HMAC signatures first**, before any other logic.
9. **RLS is enabled on every table.** Service-role access only inside Edge Functions.
10. **No comments in code unless the code is genuinely non-obvious** — and then explain *why*, not *what*.

## 7. Money-path guardrails (highest scrutiny)

These paths require tests written **before or alongside** the feature, and a step-by-step rupee-trace in the response when changed:

- `reserve_order` RPC (hold, decrement, expiry)
- Razorpay order creation + `razorpay_webhook` handling (signature verification, idempotency — a replayed webhook must not double-credit)
- `confirm_pickup` (QR/OTP validation, window check, COD cash marking)
- Payout batch math (gross − commission − fee share = net; must reconcile to the paisa)
- Refund initiation

Idempotency is mandatory on all payment webhooks: use Razorpay `payment_id`/`order_id` as a unique key.

## 8. UX constraints (product rules an agent must respect)

- Vendor listing creation must be completable in **≤ 60 seconds** — minimize steps, smart defaults (pickup window auto-fills from closing time, price auto-suggested).
- Listing photos must be captured **in-app camera only** (gallery upload blocked); EXIF `taken_at` ≤ 15 min old and geotag within 500 m of the restaurant, validated server-side in an Edge Function.
- Veg is the **default** diet filter for new buyers. Jain is a first-class filter option (Mumbai market requirement).
- Never use the word "leftover" in any user-facing copy. Approved framing: "Cooked today, for today."
- Every listing displays: price, original value, pickup window, prep time, consume-by time, vendor rating.
- Buyer-facing copy is English + simple Hindi-friendly phrasing (v1); no regional slang.

## 9. Working method with this founder

- **Decision authority: the founder.** Any critical, important, or architectural decision must be **confirmed by the founder before implementation** — the agent must never take such decisions on its own. This includes (non-exhaustive): changing the data model or schema, adding/removing/swapping libraries, services, or infrastructure, altering state machines, API contracts, money/payment flows, security behavior, pricing or fee logic, choosing between viable implementation approaches with materially different trade-offs, and anything not explicitly covered by the docs. When such a decision point arises: stop, present the options with trade-offs and a recommendation in plain language, and wait for the founder's explicit approval. Only genuinely trivial, doc-covered implementation details (naming, file layout, code style) may be decided autonomously.
- The founder cannot read code. Every response must include a short plain-language summary of: what changed, why, what they need to do manually (if anything), and how to verify it works.
- Prefer the smallest change that completes the task. Do not refactor working code unprompted; do not add features not requested; do not add libraries without stating why.
- If a request is ambiguous, check `doc/` first — the answer is usually there. If genuinely blocking, ask one specific question rather than guessing on money, legal, or food-safety topics.
- When the founder reports a bug, reproduce it mentally against the state machines in `doc/02` before changing code; explain the root cause in one sentence.
- CI must stay green. If a change breaks `flutter analyze`, tests, or the web build, fixing that is part of the same task.

## 10. Explicitly out of scope (do not build without instruction)

Delivery/logistics, iOS builds, multi-city support, WhatsApp bot, ML/AI quality scoring, Kubernetes/microservices, custom auth servers, admin analytics beyond `doc/04` §4 scope, social features, reviews of *other* buyers, in-app chat.

## 11. Definition of done (every task)

1. Code written per docs, conventions above followed.
2. Analyze/lint/typecheck/test all pass locally.
3. New money/logic paths have tests.
4. `audit_logs` covers every new state transition.
5. Docs updated if and only if the design changed (same commit).
6. Plain-language summary + verification steps provided to the founder.
