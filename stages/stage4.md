# Stage 4 — Admin + NGO Web Console (Next.js)

> **Status:** ⬜ Not started
> **Started:** — · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 2

---

## 1. Objective

Build the internal web console (`console/`) used by the founders (admin) and verified NGOs. This is built **before any mobile app** because vendor recruitment (the #1 risk) cannot start without a working verification queue. Scope per `doc/02-user-flows.md` §3–4 and `doc/05-api-spec.md` §4–5.

## 2. Prerequisites

- [ ] Stage 1 complete (console scaffold, lint/typecheck/build green)
- [ ] Stage 2 complete (schema + RLS)
- [ ] Stage 3 complete (RPCs for verification, claims, disputes, dashboard)

## 3. Task checklist

### 3.1 Auth & shell
- [ ] Admin login (Supabase phone OTP; admin role checked server-side)
- [ ] Layout: sidebar (Queues, Audit, Disputes, NGOs, Ops, GST), Mumbai-IST clock in header
- [ ] Route guards — non-admin sees nothing but a denial screen

### 3.2 Verification queues
- [ ] Vendor queue: pending list → detail (FSSAI number, photos, payout info) → approve / reject+reason (writes `audit_logs`)
- [ ] NGO queue: document checklist → verify / reject
- [ ] FSSAI expiry tracker with lapsed-license highlight

### 3.3 Listing audit
- [ ] Anomaly flags: photo EXIF older than listing, reused-photo hash matches, geotag mismatch
- [ ] One-click delist with reason (suspension ladder entry point)

### 3.4 Disputes / incidents console
- [ ] Open incidents list → order timeline (photos, stamps, QR log, audit trail)
- [ ] Resolve: refund (calls refund path) / warning / delist7 / delist30 / ban + note
- [ ] Suspension ladder state visible per vendor

### 3.5 Ops dashboard (Mumbai)
- [ ] Per-cluster cards: live boxes, listed/sold/donated/wasted today, **sell-through %** (north star)
- [ ] GMV, take-rate revenue, payment-fee spend
- [ ] Vendor flake-rate table; buyer strike table
- [ ] Weekly payout batch status

### 3.6 Compliance
- [ ] GST ledger export (CSV) per `doc/07` §4 — model-agnostic (`gst_collected_paise` per payment), works under either GST model decision

### 3.7 NGO portal (separate simple area)
- [ ] NGO login → open donation broadcasts within 5 km → claim (atomic) → mark picked up → report beneficiaries

### 3.8 Quality gates
- [ ] `npm run lint`, `npx tsc --noEmit`, `npm run build` all green
- [ ] No `service_role` key in any client bundle (admin ops via RPC/service-role-aware server actions only)
- [ ] All admin actions produce `audit_logs` rows

## 4. Deliverables

- `console/` — complete Next.js app (auth, queues, audit, disputes, ops dashboard, GST export, NGO portal)
- README section in `console/` describing local run steps

## 5. Acceptance criteria

1. Founder (as admin) can approve/reject a seeded vendor end-to-end; vendor status changes and audit row appears.
2. Seeded incident can be resolved with a refund decision; order flips to `refunded`.
3. NGO portal: seeded NGO claims a seeded donation; listing flips to `donated`; beneficiary count saves.
4. Ops dashboard shows correct sell-through % for the seed data (AI shows the arithmetic).
5. Lint/typecheck/build clean; CI green.

## 6. Founder manual steps

- Provide admin phone number to be seeded as admin.
- Deploy console to Vercel (AI gives click-by-click Vercel import steps) — optional this stage, required by Stage 8.

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| — | none yet | — | — | — |

## 8. Status & dates

- Planning: done.
- Execution: not started. Blocked on Stage 3 (queues need RPCs).
