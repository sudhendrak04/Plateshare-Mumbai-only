# 12 — AI Development Guide (how this repo gets built)

**Context:** 2-person team, no dev experience, all code AI-written. This doc defines the build order, the working method, and the guardrails so AI-generated code doesn't sink the money paths.

## 1. Golden rules for AI-assisted development

0. **The founder approves all critical decisions.** Any critical, important, or architectural decision — schema/data-model changes, library or service choices, state-machine or API changes, payment/money-flow logic, security behavior, or any choice between approaches with materially different trade-offs — must be **confirmed by the founder during coding before implementation**. The agent presents options + trade-offs + a recommendation, then waits. Only trivial, doc-covered details (naming, style, file layout) are decided autonomously.
1. **Money paths get tests before features.** Any change to `reserve_order`, `confirm_pickup`, payout math, or webhook handling ships with SQL/unit tests first. These are the four places a bug costs real rupees.
2. **One feature = one conversation = one PR.** Small, reviewable increments. Never "build the whole app" in one prompt.
3. **The docs folder is the source of truth.** When AI-generated code conflicts with `03-data-model.md` or `05-api-spec.md`, the docs win — update code, not docs (unless the design genuinely changes; then update the doc in the same commit).
4. **Never hardcode secrets.** Razorpay keys, service keys → environment variables / Supabase dashboard. AI must be told this every session.
5. **Staging before prod, always.** Razorpay test keys until Week 4 gate.
6. **Every state transition must write `audit_logs`.** If the AI's code forgets, reject the change.

## 2. Build order (dependency-driven)

```
Phase 0  Repo + tooling            (Week 1)
         git init, Flutter apps scaffold, Supabase CLI project,
         GitHub Actions (analyze/test/APK), folder structure
Phase 1  Data layer                (Week 1–2)
         SQL migrations from 03-data-model.md, RLS policies,
         seed script (fake vendors/listings for dev)
Phase 2  Admin console             (Week 2)  ← FIRST UI, not the buyer app
         Next.js: vendor verification queue, NGO queue, ops dashboard
         (You cannot recruit vendors without verification working)
Phase 3  Vendor app                (Week 2–3)
         auth → restaurant registration → listing creation (camera/EXIF)
         → order queue → QR scan → donate button
Phase 4  Buyer app                 (Week 3–4)
         auth → discovery (map+list) → reserve → Razorpay test checkout
         → QR display → rating → report
Phase 5  Jobs + notifications      (Week 4)
         pg_cron sweeps, Edge Functions, FCM, MSG91, template table
Phase 6  Payments go live          (Week 4–5, AFTER CA gate)
         Razorpay live keys, Route setup, webhook hardening, payout batch
Phase 7  Polish + launch           (Week 5–7)
         Sentry, PostHog, promo engine (₹49), Play Store release
```

Rationale: admin + vendor before buyer. Supply-first is the strategy; the tooling order must match it.

## 3. Folder structure (target)

```
PlateShare/
├── doc/                    ← these files
├── apps/
│   ├── buyer/              Flutter
│   └── vendor/             Flutter
├── console/                Next.js admin + NGO
├── supabase/
│   ├── migrations/         SQL (from 03)
│   ├── functions/          Edge Functions (Deno TS)
│   └── seed.sql
├── .github/workflows/
└── README.md
```

## 4. Prompt patterns that work (use these)

- *"Implement [X] exactly per doc/05-api-spec.md section N and doc/03-data-model.md. Write the SQL migration first, then the RLS policy, then the RPC, then a test. Ask me for any ambiguity before coding."*
- *"Review this change against doc/12-ai-dev-guide.md golden rules. List violations."*
- *"Generate the pg_cron sweep job for listing expiry per doc/04-architecture.md §4, including the no-show strike logic. Include a test that simulates a window passing."*
- *"Explain this error to me like I've never coded, then fix it, then tell me how to verify the fix myself."*

## 5. Verification rituals (non-coders can do these)

| Ritual | How |
|---|---|
| Daily staging smoke test | Script: create listing as fake vendor → reserve as fake buyer → simulate webhook → confirm pickup. AI writes it; you run one command |
| Money-path review | Before any payment merge: ask AI to walk through the flow step-by-step against 07 §1–2 and show where each rupee lands |
| Demo-driven development | Every Friday: record a 2-min screen demo of the week's feature. If you can't demo it, it's not done |
| Vendor reality check | Every feature must pass the "60-second test": can a busy bakery owner do this in 60 seconds? |

## 6. Known AI-coding pitfalls in THIS project

| Pitfall | Guard |
|---|---|
| Floats for money | Docs mandate paise integers; grep for `double`/`float` in payment code |
| Client-trusted pricing | Price/discount re-validated server-side in `create_listing` RPC |
| Race on last box | Only via the guarded `UPDATE ... WHERE qty_left > 0` — never read-then-write |
| Webhook forgery | HMAC signature verification is the first line of every Razorpay handler |
| Timezone bugs | UTC everywhere server-side; IST only at render. India has no DST — one less trap, but still test midnight boundaries |
| Over-engineering | If AI proposes microservices/Kubernetes/custom auth → reject; cite 06 §2 rejections |
