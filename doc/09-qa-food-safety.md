# 09 — Food Quality Assurance System

**Premise:** nobody can taste-test food at scale. Quality is engineered through **evidence, accountability, and consequence** — not promises.

## 1. The 8-layer QA stack

| # | Layer | Mechanism | Implementation |
|---|---|---|---|
| 1 | **Vendor gate** | Only FSSAI-licensed vendors; license expiry tracked; auto-suspend on lapse | `restaurants.fssai_license` + expiry job |
| 2 | **Self-certification with teeth** | Mandatory `prep_time` + `consume_by` on every listing; displayed prominently; vendor SOP agreement signed at onboarding | Schema checks; T&C |
| 3 | **Photo evidence** | In-app camera only (gallery blocked); EXIF `taken_at` ≤ 15 min old; geotag within 500 m of restaurant; reused-photo detection (perceptual hash) | Edge Function validation; `listings.photo_geo/taken_at` |
| 4 | **Category blocklist** | High-risk items banned: raw/undercooked seafood, cut fruit, cream/custard desserts, day-old cooked food, anything reheated from previous day | `blocked_categories` table; enforced at listing creation |
| 5 | **Buyer loop** | Star rating + structured tags (freshness/quantity/value); report-a-problem with mandatory photo | `ratings`, `incidents` |
| 6 | **Refund-first disputes** | Instant refund on substantiated report; vendor must respond in 24h; platform arbitrates | Dispute console |
| 7 | **Mystery-shop audits** | Founder/team orders as regular buyers weekly per cluster; documented checklist (packaging, temp, stamps, hygiene) | Manual; `audits` log |
| 8 | **Suspension ladder** | 1st substantiated issue → warning + refund; 2nd → delist 7d; 3rd → delist 30d/ban | Admin console |

## 2. Launch risk reduction

- **Start bakery-only:** packaged/baked goods are the lowest food-poisoning risk and the easiest trust story ("packed today at 6 PM, eat by 10 PM").
- Hot cooked meals enter only in v1.1 after: 30+ clean vendor months in aggregate, incident rate < 0.5%, audit process running.
- **Floor guarantee:** "Worth at least 2× what you pay" — quantifies the buyer's risk away (Morsel's rule).

## 3. Freshness disclosure standard (adopt Plenti's norm)

Every listing and every pickup screen shows:
```
Prepared:  6:45 PM today
Consume by: 10:30 PM today
Veg only · Packed hot · Allergens: ask vendor
```
Vendors are encouraged (v1.1: reminded) to print/attach a sticker with the same data — physical + digital match builds the habit.

## 4. Incident SOP (when someone reports illness)

```
1. Buyer reports via app (or email/hotline) → incident auto-opens, order frozen
2. Auto-refund issued immediately (goodwill, no admission of fault)
3. Within 4h: founder contacts buyer directly (call), collects details
4. Evidence review: listing photo, EXIF, prep/consume stamps, other orders
   from same listing that night, vendor history
5. Vendor response required in 24h (written)
6. Outcomes: vendor warning / delist / ban; if serious illness alleged:
   suspend vendor pending review; document everything
7. If multiple reports from same vendor within 30 days → immediate delist 30d
   + mandatory re-verification
8. All steps → audit_logs (this file trail is our legal shield)
```

## 5. Metrics watched weekly

| Metric | Alert threshold |
|---|---|
| Incident rate per 100 orders | > 1.0 → pause new vendor onboarding, audit top-5 flagged vendors |
| Avg rating | < 4.2 citywide → investigate |
| Vendor rating | < 3.5 → automated review |
| Photo-EXIF rejection rate | > 15% → vendor UX problem or gaming attempt |
| Repeat-issue vendors | any with 2+ in 30 days → on admin dashboard |
