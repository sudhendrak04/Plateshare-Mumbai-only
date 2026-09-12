# 07 — Payments, Refunds, No-Show Policy & Compliance

## 1. Payment methods (v1: both, per founder decision)

### 1.1 Prepaid UPI (default)
- Flow: reserve (10-min hold) → Razorpay Checkout (UPI intent first, cards/wallets as fallbacks) → webhook `payment.captured` → order = paid.
- Razorpay Checkout Flutter SDK handles all instruments; we present UPI-first ordering.
- **New-merchant offer:** 0% platform fee for first 90 days or ₹5L GMV (₹199 one-time KYC). Steady state: 2% + 18% GST = **2.36% effective**.

### 1.2 COD (Pay at Pickup) — trust-gated
| Rule | Value |
|---|---|
| Eligibility | trust_score ≥ 70 (starts 50; +5 per successful pickup, −20 per no-show) |
| First-time buyers | Prepaid only for first 2 orders |
| Strike system | 3 no-shows in 90 days → COD disabled 30 days; prepaid still allowed |
| Vendor side | Vendor marks `cod_collected` at pickup; daily COD reconciliation in vendor app (cash ledger) |
| Abuse guard | COD orders don't decrement publicly visible qty until confirmed? — **No**: they hold inventory like prepaid, but hold expires 15 min before window end if unconfirmed |

### 1.3 Why both matters in Mumbai
Students/migrant workers sometimes lack UPI balance at month-end; COD converts them. But COD no-shows waste food that can't be re-listed — hence the gate. Expect 20–40% COD no-show rate initially; the strike system is what keeps vendors listing.

## 2. Refunds & no-shows

| Situation | Policy |
|---|---|
| Buyer cancels while `reserved` | Auto: hold released, nothing charged (prepaid hasn't captured yet) |
| Vendor cancels/under-delivers before window | Full auto-refund + ₹20 coupon credit |
| Buyer reports problem (freshness/quantity) with photo | **Refund-first**: instant full refund, incident opens for review afterwards. Buyer trust is cheaper than vendor defense |
| Buyer no-show (prepaid) | Payment forfeited (food can't be re-listed); strike; optional ₹20 goodwill coupon after 1st offense only |
| Buyer no-show (COD) | Strike only |
| Vendor no-show (listed but empty-handed) | Buyer auto-refund; vendor flake-rate recorded; 2 flakes → delist 7 days |
| Refund mechanics | Razorpay refund API (free to process); T+3–5 back to source; in-app status shown |

## 3. Vendor payouts

- Weekly cycle (Monday batch for prior Mon–Sun `picked_up` orders).
- Math per order: `net = amount − platform_commission(₹5 after free period) − payment_fee_share` — **decision:** vendor absorbs Razorpay fee in v1 (simplest; disclosed in vendor terms) — revisit at scale.
- Mechanism: **Razorpay Route** linked accounts (vendor KYC once) → automatic split at capture, weekly settlement. Fallback: manual NEFT batch via RazorpayX Payouts.
- COD cash: vendor keeps cash; platform deducts its ₹5 commission from their next prepaid payout batch (ledger line: `cod_commission_due`).

## 4. GST compliance — the one legal blocker

Two possible structures:

| | **Model A: Platform as ECO (Sec 9(5))** | **Model B: Vendor as seller of record, platform = listing agent** |
|---|---|---|
| Who charges 5% GST | Platform collects & deposits on restaurant food sales (like Zomato/Swiggy) | Vendor charges & deposits; platform invoices vendor for commission (18%) |
| Our ledger burden | Track & deposit 5% per transaction; monthly GSTR filing support | Just our own commission GST |
| Vendor burden | Must still report turnover; no output tax on platform sales | Full normal burden |
| Risk | Compliance-heavy from day 1 | Depends on whether our role legally qualifies as "agent" vs ECO — needs CA opinion |

**Action required before first transaction:** one CA consult (~₹3–5k) to pick the model and confirm documentation. The schema already stores `gst_collected_paise` per payment, so either model is supportable. Do NOT launch paid transactions before this is resolved.

## 5. FSSAI & food-safety compliance posture

- Vendors must hold valid FSSAI license/registration — verified at onboarding, expiry tracked, auto-suspend on lapse.
- Platform position: **technology intermediary**; vendor = Food Business Operator and seller of record. Terms of service state this explicitly.
- Donation channel follows **FSSAI Surplus Food Regulations 2019**: safe food only, handed over within shelf life, records kept, veg/non-veg segregated, distribution org licensed. Our `donations` table + receipts provide the required record trail.
- No Good Samaritan immunity exists in India for food donation — the compliance trail is the mitigation, plus the 2019 regs' protection for distribution organizations (liability only for intent/gross negligence).

## 6. Consumer protection & terms

- Buyer T&C: food is perishable, consume-by time displayed, no warranty beyond vendor's statutory obligations, dispute window 24h.
- Vendor agreement: freshness attestation, SOP checklist, suspension ladder, seller-of-record clause, commission schedule.
- Privacy: phone number = identity; DPDP Act 2023 basics — consent screen, data deletion request path, no data sale. (AI can draft; lawyer review before public launch.)
