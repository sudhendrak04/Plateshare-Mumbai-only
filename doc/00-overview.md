# Plate Share — Project Overview

> **Status:** Planning complete → Build phase
> **Owner:** Sudhendra + 1 teammate (2-person team, no prior dev experience — AI-assisted development)
> **Last updated:** Sep 2026

---

## 1. One-line vision

A mobile marketplace where Mumbai restaurants, cafés, and bakeries sell their unsold surplus food as discounted "mystery boxes" (30–50% off) for self-pickup near closing time — instead of throwing it away.

## 2. Core loop

```
Vendor lists surplus box (evening, before closing)
        ↓
Buyer nearby discovers it → pays (UPI) or reserves (COD)
        ↓
Buyer picks up in the time window (QR verification)
        ↓
Buyer rates the box → vendor earns trust score
        ↓
Unsold boxes → one-tap donate to verified NGO (Roti Bank / RHA)
```

## 3. Launch scope (v1) — Mumbai only

| Decision | Choice |
|---|---|
| City | Mumbai only |
| Launch micro-markets | **Andheri West + Vile Parle** (station-clustered, dense restaurants, NMIMS/Mithibai students) |
| Second wave (post-validation) | Dadar, then Ghatkopar/Powai |
| Verticals | **Bakeries + cafés first** (lowest food-safety risk). Cloud kitchens / hot meals in v1.1 |
| Supply acquisition | 30–50 vendors onboarded in the 2 clusters *before* buyer marketing |
| Demand seeding | Students & PG residents (₹49 rescue-pack promo) |

## 4. Explicit non-goals for v1

- ❌ Delivery (pickup only — delivery destroys the 50%-off economics)
- ❌ Hot cooked full-meal boxes from full-service restaurants (food-safety liability) — comes in v1.1
- ❌ Tier-2 cities / other metros
- ❌ iOS at launch (Android-first; Flutter keeps iOS possible later)
- ❌ WhatsApp concierge MVP (app-first per founder decision; WhatsApp later as vendor convenience layer)
- ❌ ML-based fraud detection / automated quality scoring (rules + manual audits suffice)

## 5. Key constraints (from founder decisions)

1. **Team:** 2 people, zero dev experience. All code written by AI. → The architecture must minimize operational complexity: managed services (Supabase), one codebase (Flutter), no Kubernetes/microservices, no custom auth servers.
2. **Payments:** Both prepaid (UPI) and COD (pay at pickup) supported from day one, with COD gated behind a trust score.
3. **Founder location:** Not physically in the launch clusters → vendor recruitment must be remote-friendly (see `10-launch-plan.md` §3 for the contact/conversion playbook).
4. **Tech stack:** Chosen for AI-writability + later scalability (see `06-tech-stack.md`).

## 6. North-star & supporting metrics

| Metric | Definition | Target at end of Month 3 |
|---|---|---|
| **Sell-through rate** ⭐ | boxes picked-up ÷ boxes listed | **> 70%** (the only metric that keeps vendors listing) |
| Active vendors | listed ≥ 1 box in last 7 days | 30 |
| Orders/week | paid + COD confirmed | 300 |
| Waste-rescue rate | (sold + donated) ÷ listed | > 85% |
| Buyer repeat rate | 2nd purchase within 14 days | > 40% |
| Vendor payout accuracy | payouts on time, zero disputes | 100% |

## 7. Document map

| Doc | Contents |
|---|---|
| `01-research.md` | Market, competitors (TGTG + 8 Indian clones), Mumbai data, regulations |
| `02-user-flows.md` | All 4 roles: flows + screen inventory |
| `03-data-model.md` | Entities, fields, relationships, state machines |
| `04-architecture.md` | System components, sequence diagrams, jobs |
| `05-api-spec.md` | Full REST endpoint inventory |
| `06-tech-stack.md` | Final stack + rationale for an AI-coded 2-person team |
| `07-payments-compliance.md` | Razorpay flow, COD rules, GST/FSSAI posture, refunds/no-shows |
| `08-notifications.md` | Trigger matrix, channels, copy |
| `09-qa-food-safety.md` | Quality assurance system, blocklist, incident SOP |
| `10-launch-plan.md` | Mumbai launch: vendor recruitment playbook, timeline, monsoon plan |
| `11-risks.md` | Risk register + open questions |
| `12-ai-dev-guide.md` | How this repo gets built by AI: order of work, prompts, guardrails |

## 8. The honest bottom line (read before building)

- **Unit economics are thin:** ~₹4.85 net per ₹79 box after payment fees and the ₹5 vendor fee. Break-even ≈ 8,000 boxes/month. For the first 6 months this is a subsidized mission, not a business. Plan runway accordingly.
- **The only real blocker is legal:** confirm the GST structure (platform as ECO under Sec 9(5) vs. vendor-as-seller-of-record) with a CA **before** the first transaction. One consult. Do it now.
- **Cold-start is the killer:** the app is worthless with 5 vendors. Supply-first, hyper-local, hand-recruited. The build order in `12-ai-dev-guide.md` reflects this: admin tools before buyer polish.
