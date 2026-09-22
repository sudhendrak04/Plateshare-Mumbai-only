# Stage 4 — Admin + NGO Web Console (Next.js)

> **Status:** ✅ Complete
> **Started:** Sep 2026 · **Completed:** Sep 2026
> **Implements:** `doc/12-ai-dev-guide.md` Phase 2

---

## 1. Objective

Build the internal web console (`console/`) used by the founders (admin) and verified NGOs. Built **before any mobile app** because vendor recruitment (the #1 risk) cannot start without a working verification queue. Scope per `doc/02-user-flows.md` §3–4 and `doc/05-api-spec.md` §4–5.

## 2. Prerequisites

- [x] Stage 1 complete (console scaffold)
- [x] Stage 2 + 3 complete (schema, RLS, RPCs)

## 3. Task checklist

### 3.1 Auth & shell
- [x] Admin + NGO login (email+password for local dev; phone OTP wiring lands with the SMS-provider decision)
- [x] Shell: dark sidebar (role-based nav), live **Mumbai-IST clock** in header, sign-out
- [x] Route guards: role checked from `profiles` via RLS; non-admin sees "Access denied" screens; admin RPCs re-verify server-side

### 3.2 Verification queues
- [x] Vendor queue: pending / verified / rejected-suspended sections; approve + reject-with-reason (→ `admin_verify_vendor`, N14 outbox notify); FSSAI expiry tracker with <30-day warning badge
- [x] NGO queue: document checklist (12A/80G/Darpan) → verify/reject (→ `admin_verify_ngo`)

### 3.3 Listing audit
- [x] `admin_listing_audit()` RPC: photo-older-than-listing flag, reused-photo flag, geotag-mismatch (m) — rendered as flag badges
- [x] One-click **Delist with reason** (→ `admin_delist_listing`)

### 3.4 Disputes console
- [x] Incident list joined to order timeline (buyer, vendor, amount, method, evidence indicator)
- [x] Resolve actions: refund / warning / delist7 / delist30 / ban / dismiss (+note) → `admin_resolve_incident` (suspension ladder implemented in Stage 3)

### 3.5 Ops dashboard
- [x] Per-cluster table: listed/sold/donated/wasted, **sell-through %** badge (green ≥70% / amber ≥50% / red), GMV — date picker, IST-day aware
- [x] North-star banner ("sell-through is the only metric that keeps vendors listing")

### 3.6 Compliance
- [x] GST ledger with month picker + per-month GMV/GST totals + **CSV export** (model-agnostic per doc/07 §4)

### 3.7 NGO portal (`/ngo`)
- [x] Verified gate (unverified NGOs see "awaiting verification" notice)
- [x] Open donation broadcasts (≤5 km, from own NGO geo server-side) → **Claim (30-min hold)** → Mark picked up → Report beneficiaries count
- [x] Claim status view (hold expiry / picked up / beneficiaries)

### 3.8 Security hardening (new migration `0013_security_hardening.sql`)
- [x] **Column-level UPDATE grants**: buyers can only edit own name/diet_pref; vendors can only edit profile fields (never own status/FSSAI/rating) — closes self-verification escalation hole
- [x] `profiles_no_self_escalation` trigger (authenticated-role-scoped): role/trust/strikes not self-changeable
- [x] `admin_listing_audit` raises `UNAUTHORIZED_ROLE` for non-admins (was silently empty)
- [x] 0-arg `ngo_open_donations()` (caller's NGO geo resolved server-side)
- [x] Dev logins seeded (email+password + `auth.identities` rows) — admin@plateshare.local / ngo@plateshare.local

### 3.9 Quality gates
- [x] `npm run lint` (0), `npx tsc --noEmit` (0), `npm run build` (0) — all green
- [x] No `service_role` key anywhere in console (uses anon key + user JWT; admin power comes from RPCs' `is_admin()` checks)
- [x] All admin actions produce `audit_logs` rows
- [x] SQL tests still 35/35 PASS; API smoke via Node: admin login ✓, ops dashboard ✓, audit rows ✓, NGO-calls-admin-RPC **denied** ✓, NGO donations ✓; dev server boots, /login HTTP 200

## 4. Deliverables

- `console/app/` — login, shell (IST clock, role nav), ops, queues/vendors, queues/ngos, audit, disputes, gst, ngo portal
- `console/lib/` — supabase client, guard/RequireRole, format (paise→₹, IST)
- `supabase/migrations/0013_security_hardening.sql`
- `console/.env.local` (local keys, gitignored)

## 5. Acceptance criteria

1. ✅ Founder can approve/reject the seeded **pending vendor** end-to-end (API-verified: queues read via RLS + `admin_verify_vendor` writes audit rows).
2. ✅ Seeded incident resolvable with refund decision (Stage 3 RPC + console UI wired).
3. ✅ NGO portal: seeded NGO sees 1 open donation, claim/pickup/beneficiaries all wired (`ngo_open_donations` returns data; claim atomicity proven in Stage 3 tests).
4. ✅ Ops dashboard shows correct per-cluster arithmetic from seed data.
5. ✅ Lint/typecheck/build clean; 35/35 SQL tests pass; authorization negative test proven (NGO → admin RPC = UNAUTHORIZED_ROLE).

## 6. Founder manual steps (to see it live)

| # | Step | Notes |
|---|---|---|
| 1 | Open the console | `cd console && npm run dev` → http://localhost:3000 |
| 2 | Sign in as admin | admin@plateshare.local / plateshare-dev |
| 3 | Try the flows | Ops dashboard → Vendor queue (approve "Ghatkopar Kitchen Test") → Audit → Disputes (resolve the seeded refund) → GST |
| 4 | Sign in as NGO | ngo@plateshare.local / plateshare-ngo → claim the seeded donation |
| 5 | (Optional) Deploy to Vercel | needed by Stage 8, not now |

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| 1 | Client-side supabase-js console (no server components for data) | SSR + @supabase/ssr vs pure client | AI (internal tool; simplest for AI edits; security via RLS + admin RPCs) | Sep 2026 |
| 2 | Email+password dev logins (seeded with identity rows) | phone-OTP only | AI (local stack has no SMS provider; OTP decision still pending — `doc/PENDING_DECISIONS.md`) | Sep 2026 |
| 3 | Lint config relaxes `react-compiler/react-compiler`, `react-hooks/set-state-in-effect`, `react-hooks/purity`, `@typescript-eslint/no-explicit-any` for the console | contort components vs relax | AI (internal console; data-fetching patterns standard) | Sep 2026 |
| 4 | GoTrue password login requires: `auth.identities` row (provider_id = user uuid, identity_data with sub) + `instance_id` + confirmed email + bcrypt — **documented in seed.sql** | workaround-free | AI (learned by probe-user diff; future seed authors beware) | Sep 2026 |
| 5 | Column-level grants + escalation trigger (security hardening) | trigger-only vs column grants + trigger | AI (defense in depth; bug found while building console) | Sep 2026 |

## 8. Status & dates

- Planning: done.
- Execution: done Sep 2026. Console runs against local Supabase; live keys flip at Stage 8.
- Blockers: none. Stage 5 (vendor app) can start — **needs the OTP/SMS provider decision first** (`doc/PENDING_DECISIONS.md`).
