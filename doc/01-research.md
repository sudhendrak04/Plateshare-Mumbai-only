# 01 — Research Summary (Market, Competitors, Regulations, Mumbai)

## 1. Too Good To Go (TGTG) — the reference model

| Stage | How TGTG works | Plate Share adaptation |
|---|---|---|
| Listing | Store sets default daily supply in "MyStore" dashboard, adjusts daily based on actual leftovers | Same, mobile-first, ≤60 seconds to list; auto-suggested price |
| Pricing | Surprise bags at ~1/3 of retail value (€3–6) | 30–50% off, minimum ₹49 floor |
| Purchase | Reserve + prepay in app | UPI prepaid default; COD as earned privilege |
| Pickup | Buyer shows in-app receipt during narrow window; store swipes to confirm | QR scan by vendor phone; no hardware |
| No-shows | Bag forfeited (can't be re-listed); repeat no-showers banned | Same + strike system; COD lockout after 3 strikes |
| Revenue | Per-order fee (~£1.09/$1.79 small bags, ~25% above threshold) + annual admin fee (~$89/£39); quarterly payouts | ₹5 flat/box after 60–90-day 0% commission period; weekly payouts |
| Onboarding | Self-serve + sales team for chains | Self-serve with FSSAI gate + manual verification |

**Key insight:** the "surprise" is deliberate — a kitchen can't know at 4pm what's left at 9pm. Mystery = what makes the deep discount sellable. Indian competitor Morsel states this directly: *"Veg or non-veg is the only choice you make."*

**TGTG has no India plans** — they told Kerala competitor Plenti that India is "too complex." No global player will compete with you soon.

## 2. Indian competitive landscape (as of Sep 2026)

| Player | Location | Differentiator | Lesson for us |
|---|---|---|---|
| **Morsel** | Bengaluru (Koramangala, HSR) | Hyper-local, ~50% off, veg/non-veg tag, self-pickup only, "cooked today for today" copy | Best positioning copy; micro-market strategy validated |
| **Perfectly Good** | Bengaluru | **No mystery** — exact dish/portion/price shown | Counter-positioning; mystery has skeptics → keep floor guarantee |
| **Plenti** | Kerala (TVM, Kochi) | 400+ vendors, 1L+ users in 6 months; **mandatory pack-time + consume-by stickers** | Adopt the freshness-stamp standard from day 1 |
| **FUDL** | India | Mystery bags, 50–70% off | Validates discount range |
| **Grabitz** | India | Surprise bags + B2B "Smart Parcels" | B2B is a later expansion lane |
| **Last Bite Eats** | India | Surplus *delivery* | Avoid: delivery economics don't work at this price point |
| **Pick'n'Treat** | India (2023) | Discounted surplus + "feed the needy" angle | Impact story works; CSR funding lane |
| **MÄNTÆ** | India | ISO-certified positioning, proprietorship | Trust badges matter |

**Verdict:** concept validated, nobody has won, all sub-scale and city-locked. Differentiation must be **trust (freshness guarantees), station-cluster density, and the NGO donation loop** — not the concept.

## 3. Mumbai-specific data

- **4,573 tonnes of food waste/day** (72.6% of Mumbai's 6,300 MT total) — BMC Environment Status Report.
- **75% of surveyed Mumbai restaurants deliberately over-prepare by 10–20%** (some 30%) — WRI India / CRB HoReCa study. This over-preparation is exactly the surplus we sell.
- Existing donation infra proves restaurant willingness: **Mumbai Roti Bank** (Dabbawala-backed, collects leftover food nightly from hotels/events) and **Robin Hood Army** (zero-funds, volunteer-run). Neither *sells* — the paid-surplus lane is open.
- **Student demand:** PG searches in Mumbai **+45% YoY** (Justdial 2026 cycle); 70+ engineering colleges; students budget **₹2,500–4,500/month on food**. ₹49–79 boxes vs. ₹120–200 meals = real saving.
- **Geography:** north–south sprawl → distance filtering is non-negotiable; cluster by **local train station** so pickup fits the commute home.
- **Monsoon (Jun–Sep):** evening walk-in pickup drops 20–30%. Needs grace windows + rainy-day inventory caps.
- **Veg/Jain sensitivity:** Matunga, Ghatkopar, Dadar are Jain-heavy → Jain + no-onion-no-garlic filters matter more than in Bengaluru.

## 4. Regulatory notes (India)

### 4.1 FSSAI
- **FSS Act 2006** — all food businesses need FSSAI license/registration. **Vendors must hold this; we verify it at onboarding.** (Mandatory gate.)
- **FSSAI Surplus Food Regulations 2019** — governs *free donation*: donor FBO must ensure food is safe, segregated, handed over before shelf-life expiry, records maintained; distribution orgs must be licensed; State monitoring committees exist. → Applies to our **NGO donation channel**, and gives the vendor a compliance-friendly donation path.
- **Discounted sale ≠ donation.** A 30–50% off sale is an ordinary food sale: the restaurant remains the Food Business Operator with full liability. Structure contracts so the **vendor is seller of record**.

### 4.2 Liability
- **No Good Samaritan food-donation immunity exists in India** (Global Food Donation Policy Atlas confirms). Restaurants' liability fear is a real sales objection → we counter with platform SOPs, the FSSAI-compliant donation trail, and the 2019 regs' protections for *distribution organizations*.
- Paid sales: Contract law + Consumer Protection Act apply (CPA product-liability claims require a paying customer — ours are paying).
- Mitigation stack: vendor-as-seller terms, incident SOP (see `09`), refund-first policy, food-safety insurance once revenue justifies it.

### 4.3 GST
- Restaurant food = **5% GST (no ITC)** standalone/cloud kitchen; 18% only at hotel "specified premises."
- **Section 9(5) CGST Act:** if we operate as an e-commerce operator (ECO) supplying restaurant services, **the platform collects & deposits the 5% GST** (like Zomato/Swiggy). If we structure as a pure agent/listing service with vendor as seller of record, treatment differs.
- ⚠️ **This is the one legal blocker. One CA consult before first transaction.** See `07-payments-compliance.md`.
- Discounts are fine — GST applies to actual documented transaction value.

### 4.4 NGO legitimacy
- Verify: **12A/12B + 80G** income-tax registrations, **NITI Aayog Darpan ID**, contact-person ID. FCRA only if foreign funds (not our case).

## 5. Cultural & logistical factors

| Factor | Implication |
|---|---|
| Veg / non-veg / egg segregation is non-negotiable | Category filter is a launch feature, not a nice-to-have; Jain filter for Mumbai |
| "Surplus" stigma = "stale/old" | Copy discipline: never "leftover." Use *"Cooked today, for today — same food someone paid full price for an hour earlier"* (Morsel's framing) |
| UPI dominance | Prepaid UPI is the default rail; COD needed for students/migrant workers but causes no-shows → trust-gated |
| Price anchor is ₹40–150, not €4 | Minimum viable box ₹49; below that payment fees eat the margin |
| Tier-1 density first | Mumbai station-clusters before any other city |

## 6. Payments cost reality (Razorpay, verified Sep 2026)

- Standard: **2% platform fee + 18% GST** on all domestic instruments incl. UPI (UPI's 0% MDR is government-mandated, but Razorpay's platform fee still applies).
- **New-merchant offer: 0% platform fee for first 90 days or ₹5L GMV** (activated on/after 1 Jul 2026) — use this window; ₹199 one-time KYC fee.
- Effective steady-state: **2.36% per transaction.** On a ₹79 box = ₹1.86. Refunds are free to process.
- Alternatives benchmarked: Cashfree, PhonePe PG. Razorpay stays (Route splits for vendor payouts + best docs for AI-generated integration code).
