# 10 — Mumbai Launch Plan

## 1. Launch geography

| Wave | Clusters | Why |
|---|---|---|
| **Wave 1 (Month 1–3)** | **Andheri West + Vile Parle** | Dense cafés/bakeries; NMIMS + Mithibai students; Western Line commuters; ~2 km walkable radius each |
| Wave 2 (Month 4+) | Dadar, Ghatkopar | Central + Jain-heavy (tests Jain filter), heavy PG population |
| Wave 3 | Powai (IIT), Churchgate/Fort | Campus + office crowds |

Rule: **do not open a new cluster until Wave-1 sell-through > 70%.** Density beats coverage.

## 2. Supply-first sequencing

```
Week 1–2   Build admin console + vendor app MVP (buyer app NOT yet public)
Week 2–6   Vendor recruitment sprint: 30–50 verified vendors across both clusters
Week 4–6   Private beta: vendor app live, boxes listed, team + friends buy manually
Week 6–7   Buyer app soft-launch: ₹49 rescue-pack promo, student ambassadors
Week 8+    Public launch if sell-through > 50%; iterate to 70%
```

## 3. Vendor recruitment playbook (founder is NOT local — remote-friendly methods)

### 3.1 Who to target (in priority order)
1. **Bakeries & bakery-cafés** (lowest-risk inventory, highest evening surplus: puffs, pav, bread, cookies)
2. **Cafés** (sandwiches, bakes, surplus beverages/snacks)
3. **Cloud kitchens** (end-of-day meal boxes — v1.1)
4. **Sweet shops** (end-of-day farsan/mithai boxes — Mumbai-specific goldmine)

### 3.2 How to find them (no physical presence needed)
| Channel | Action |
|---|---|
| Google Maps scrape | Search "bakery/café" within 1.5 km of Andheri West & Vile Parle stations → build a sheet: name, phone, hours, rating |
| Zomato/Swiggy listings | Cross-reference; kitchens already comfortable with platform economics |
| Instagram | Local food-page DMs; cafés respond to DMs faster than calls |
| CA/association angle | Bakeries' associations, local FSSAI consultants (they know which clients have licenses) |
| Walk-in proxy | Hire 1 part-time field person in Mumbai (~₹10–15k/month) for 6 weeks — **this is the single highest-ROI spend**; founder does video-call closings |

### 3.3 The pitch (what convinces them)
Lead with **their loss, not the planet**:
- "You already throw away ₹500–2,000 of unsold stock every night. We turn that into cash you'd otherwise bin. Zero effort: one tap, and we send you buyers in your last 45 minutes."
- **Zero commission for 90 days** (then flat ₹5/box — never quote a %; Swiggy/Zomato commission trauma is real).
- **No delivery, no packaging change** — buyer walks in, you hand a bag.
- **Free marketing + new customers** who then pay full price other days.
- **FSSAI-compliant donation button** — unsold stock goes to Roti Bank/RHA with a receipt for CSR records (kills the liability fear).
- Show the 60-second listing demo on your own phone. Close with: "List your first box tomorrow evening — we'll have 3 buyers waiting."

### 3.4 Objection handling
| Objection | Answer |
|---|---|
| "Surplus food = stale food, reputation risk" | "It's the same food you sold at full price an hour ago. Freshness stamps on every listing; we delist vendors who cut corners — protects you too." |
| "Liability if someone gets sick" | "You remain the seller as per FSSAI norms — same as your normal counter sales. We add photo evidence + timestamps that protect you in disputes." |
| "No time for another app" | "60 seconds a day. WhatsApp bot listing coming (reply '5 veg boxes')." |
| "What if nobody buys?" | "You lose nothing — the food was going in the bin. First 90 days zero commission." |

### 3.5 Demand seeding
- Student ambassadors at NMIMS/Mithibai/Podar (₹2–5k/month + free boxes): WhatsApp-group + campus-poster distribution.
- ₹49 first-box promo; referral: both sides get ₹20 credit.
- Partner with 2–3 large PG operators near the clusters (they *want* cheaper food options for residents).
- Press angle (Mumbai food-waste story: 4,573 MT/day) — local PR is free and vendors respect coverage.

## 4. Monsoon plan (Jun–Sep)
- Grace window +10 min default during monsoon (schema already supports `grace_min`).
- In-app weather flag: "Heavy rain — pickup windows extended tonight."
- Vendors advised to cap box quantities on red-alert days.
- Expect 20–30% pickup drop; don't panic-adjust the model in July.

## 5. 12-week timeline

| Week | Milestone |
|---|---|
| 1–2 | Repo + Supabase + admin console (vendor verification works end-to-end) |
| 2–3 | Vendor app: signup, FSSAI verification, listing creation |
| 3–4 | Buyer app: discovery, reserve, Razorpay test-mode payments |
| 4 | CA consult → GST model locked (07 §4) — **before any real money** |
| 4–6 | Razorpay live keys, vendor recruitment sprint (parallel), private beta |
| 6–7 | Buyer soft-launch, ₹49 promo, ambassadors active |
| 8 | Public launch decision gate: sell-through > 50% |
| 9–12 | Iterate: WhatsApp vendor bot (v1.1), hot-meal category pilot, Dadar prep |

## 6. Budget (first 3 months)

| Item | ₹ |
|---|---|
| Tech infra (per 06) | ~30,000 |
| Field person (6 weeks × 2 clusters) | 45,000 |
| Student ambassadors (3 × ₹3k) | 9,000 |
| CA + basic legal docs | 15,000 |
| Promo credits + printing | 10,000 |
| Buffer | 20,000 |
| **Total** | **~₹1.3 lakh** |
