# 11 — Risks & Open Questions

## 1. Risk register (ranked)

| # | Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| 1 | **Cold-start / chicken-and-egg** — buyers won't open an app with 5 vendors; vendors won't list for 10 buyers | 🔴 Critical | Certain if mishandled | Supply-first: 30–50 vendors before buyer marketing; micro-market density; field person; sell-through is the north star |
| 2 | **Unit economics** — ~₹4.85 net/₹79 box; break-even ≈ 8,000 boxes/month | 🔴 Critical | Certain at start | 6-month funded runway mindset; Razorpay 0% offer window; flat ₹5 fee not %; CSR/impact-grant option (Pick'n'Treat lane); do NOT scale spend before sell-through proves out |
| 3 | **Food-safety incident** — one viral story kills the category | 🔴 Critical | Low–Med | Bakery-only start; QA stack (09); blocklist; refund-first; incident SOP; insurance once revenue justifies |
| 4 | **GST/ECO legal structure unresolved** — Sec 9(5) exposure if we're an ECO | 🔴 High | Certain until resolved | CA consult Week 4 — the only true launch blocker |
| 5 | **Vendor habit formation** — the competitor is the vendor forgetting to list | 🟠 High | High | 60-second listing; 17:30 nudge (N9); WhatsApp bot v1.1; show daily sell-through stats to reinforce |
| 6 | **COD no-shows** erode vendor trust ("packed 5, came 2") | 🟠 High | High | Prepaid default; trust-gated COD; strike system; holds expire pre-window-end |
| 7 | **Monsoon pickup collapse** (Jun–Sep) | 🟡 Medium | Seasonal-certain | Grace windows; weather flag; inventory caps; launch timing avoids deep monsoon |
| 8 | **Competitive crowding** — 8 Indian clones live | 🟡 Medium | Certain | Differentiate on trust (freshness stamps, floor guarantee), station-cluster density, NGO donation loop |
| 9 | **Vendor flaking** (listed but empty-handed) | 🟡 Medium | Medium | Flake-rate tracking; delist ladder; buyer auto-refund |
| 10 | **AI-written code defects** in payments/inventory paths | 🟡 Medium | Medium | Test-first on money paths; staging with Razorpay test keys; audit_logs everywhere; no live money until CA + tests pass |
| 11 | **Regulatory drift** — FSSAI extends surplus regs to commercial resale | 🟢 Low | Low | Vendor-as-seller-of-record posture; monitor FSSAI notifications |
| 12 | **Founder not local** — ops blind spot | 🟡 Medium | High early | Field person hire; weekly mystery shops; vendor WhatsApp group for signal |

## 2. Open questions (owner + deadline)

| # | Question | Owner | When |
|---|---|---|---|
| 1 | ECO vs. agent GST model? | Founder + CA | Week 4 (hard gate) |
| 2 | Food-safety/product liability insurance quote? | Founder | Month 2 |
| 3 | Field person sourced? (job spec in 10 §3.2) | Founder | Week 2 |
| 4 | NGO partners confirmed? (Mumbai Roti Bank, RHA Mumbai) | Founder | Week 3 — cold email + one meeting; they benefit (free supply pipeline) |
| 5 | Razorpay account + KYC done (needs business entity)? | Founder | Week 1 — **entity registration (LLP/Pvt Ltd or proprietorship) is a prerequisite for the gateway and payouts** |
| 6 | Play Store developer account + app signing? | Founder | Week 1 |
| 7 | Exact cluster boundaries (station radius walk-shed)? | Founder + maps | Week 2 |
| 8 | Buyer app language: English + Hindi at launch? Marathi for Wave 2? | Founder | Week 5 |
| 9 | What's the minimum sell-through at which you'd personally keep funding month 4–6? | Founder | Before launch |

## 3. Kill criteria (pre-agreed honesty)

- Week 10: < 20 active vendors OR sell-through < 35% → stop, run the WhatsApp concierge test instead before more code.
- Month 4: < 150 orders/week → do not expand clusters; fix density or pricing.
- Any food-safety incident with hospitalization → pause new onboarding citywide, full SOP review (09 §4).
