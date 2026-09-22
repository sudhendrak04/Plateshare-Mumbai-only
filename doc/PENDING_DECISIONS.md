# PENDING DECISIONS

> Open technical/business decisions deferred by the founder. Each item: context, options, trade-offs, and "how to finalize."
> **Rule (per `AGENTS.md` §9):** do not implement around these — surface them to the founder when the relevant build phase arrives.

---

## 1. OTP / SMS provider

**Status:** Deferred
**Touches:** Auth (phone OTP), `doc/06-tech-stack.md`, `backend/backend_plan.md` §10

### Context
Supabase Auth phone-OTP natively supports: **Twilio, MessageBird, Textlocal, Vonage** (no custom code). **MSG91 is not native** — it requires a custom "Send SMS" hook, which is a **Pro-plan feature**.

### Options

| Option | Cost | Complexity | Notes |
|---|---|---|---|
| **Twilio (native)** | Higher per-SMS in India | Zero custom code | Works on free tier; DLT-compliant via Twilio's India setup |
| **MSG91 (custom hook)** | Cheaper per-SMS | Custom Send-SMS hook + **Pro plan** | Not possible on free tier |

### Trade-off
- Twilio = simplest, ships immediately on free tier, higher ongoing SMS cost.
- MSG91 = cheaper at scale, but requires paying for Pro now.

### How to finalize
Decide when we reach the auth implementation phase (build Phase 3, `doc/12-ai-dev-guide.md` §2). Until then, **transactional SMS** (pickup alerts, refunds — separate from OTP) is unaffected and can still use MSG91 via a direct Edge Function call on any plan.

---

## 2. Vendor payout mechanism

**Status:** Deferred
**Touches:** Payments, `doc/07-payments-compliance.md` §3, `backend/backend_plan.md` §9

### Context
Two ways to move vendor money:

| Option | How | Pros | Cons |
|---|---|---|---|
| **Platform collect + weekly NEFT** (RazorpayX Payouts) | All money lands in your Razorpay account; weekly NEFT to vendors | Simplest; keeps money model flexible while GST/ECO is unresolved; no per-vendor Route KYC | Manual-ish weekly batch; vendor gets money weekly, not instantly |
| **Razorpay Route auto-split** | Split vendor share automatically at capture via linked accounts | Real-time vendor settlement; less ops | Locks in commission model now; per-vendor Route KYC/onboarding; more complex |

### Trade-off
- Platform-collect is safer to start (the GST/ECO structure is still unresolved — don't hard-code a split that may change).
- Route is the long-term answer for scale but premature in v1.

### How to finalize
Decide **after** the CA consult resolves the GST model (`doc/07` §4, Week 4 gate) — the tax answer will likely dictate the payout design. Default recommendation until then: **platform collect + RazorpayX weekly NEFT**.

---

## Resolved decisions log

| # | Decision | Outcome | Date |
|---|---|---|---|
| 1 | Supabase plan | Free tier for now | Sep 2026 |
| 2 | backend_plan.md scope | Concise reference first, full build spec later | Sep 2026 |
| 3 | backend file location | `backend/backend_plan.md`; pending decisions in `doc/PENDING_DECISIONS.md` | Sep 2026 |
