# 02 — User Roles & Core Flows

Four actor types: **Vendor**, **Buyer**, **NGO**, **Admin**. Two apps (Buyer, Vendor) + one web console (Admin/NGO — NGO can be a simple web view in v1).

---

## 1. VENDOR (Restaurant / Café / Bakery / Cloud Kitchen)

### 1.1 Onboarding & KYC

```
1. Install vendor app → mobile OTP signup (MSG91)
2. Outlet profile:
   - name, cuisine tags, address (auto pin via map), open/close hours
   - food type: Pure-Veg | Veg+Non-Veg | Egg allowed
   - FSSAI license number  (MANDATORY — verified against registry)
   - GSTIN (optional), PAN
   - 3+ outlet photos, 1 menu photo
3. Payout setup: bank account + UPI ID → penny-drop verification
4. Accept: Platform SOP agreement (food-safety checklist, dispute policy)
5. Status: PENDING → admin verifies (24–48h SLA) → VERIFIED badge
   Rejection reason shown in-app if FSSAI invalid
```

### 1.2 Daily listing flow (target: ≤ 60 seconds)

```
1. Home shows "Today's plan": boxes listed today, orders pending, yesterday's stats
2. Tap [Create Box]:
   - Category: Veg | Non-Veg | Egg | Jain-friendly
   - Quantity: N boxes (stepper)
   - Contents hint: free-text short line, e.g. "2 pav + 1 vada + 1 cookie"
     (category-level, NOT exact dish — mystery is the model)
   - Original value: ₹X → app auto-suggests price = 40–60% off, floor ₹49
   - Pickup window: auto-default = last 45 min before closing time
     (editable start/end + grace minutes)
   - Photo: MUST be captured in-app now (camera only, EXIF/geotag kept,
     gallery upload blocked)
   - prep_time + consume_by: auto-stamped from listing time; editable
3. [Publish] → live instantly in buyer feed
4. Anytime: edit qty up/down (never below already-sold), mark Sold Out
5. At window close: unsold boxes auto-expire → one-tap
   [Donate to NGO] → broadcast to nearby verified NGOs
```

### 1.3 Order management

```
- Live order list: #id, buyer first name, qty, prepaid ✓ / COD, status
- Buyer arrives → vendor taps [Scan] → camera opens → scan buyer QR
  (fallback: buyer reads 6-digit OTP aloud → vendor types it)
- Success → order = PICKED_UP. COD orders: vendor collects cash,
  app records it for reconciliation
- End of day: summary — sold / donated / wasted, revenue, impact stats
  (meals rescued, est. CO₂e saved) → screenshot-friendly for social media
```

---

## 2. BUYER (Individual — student / professional / migrant worker)

### 2.1 Discovery

```
1. Phone OTP signup → optional name; set diet preference (Veg default ON)
2. Home = split view: Map (live pins) + Card list
   Default filter: ≤ 2 km, closing soonest first
   Filters: Veg/Non-Veg/Egg/Jain · distance · price · pickup window · cuisine
3. Card shows: photo, "worth ₹180 → ₹79", pickup window + countdown,
   prep-time & consume-by stamps, vendor rating ★, "3 left"
4. [Reserve] → 10-minute hold (Redis TTL) → pay UPI (default)
   or select Pay at Pickup (if trust score allows)
```

### 2.2 Order → pickup → feedback

```
5. Confirmation screen: order ID + QR code + window + directions button
6. T-15 min: push "Window closes 9:30 PM — show your QR"
7. At counter: show QR → vendor scans → confirmation animation
8. Same night: rate ★1–5 + tags (Quantity / Freshness / Value)
9. Problem? [Report an issue] + photo → auto-refund path (see 07/09)
10. No-show: box forfeited at window close; strike recorded;
    3 strikes → COD disabled 30 days (prepaid still allowed)
```

---

## 3. NGO / BULK BUYER

### 3.1 Registration & verification (manual, 48–72h)

```
1. Web form (no app needed in v1): org name, registration numbers
   (12A/12B/80G), Darpan ID, contact person + ID proof, service area
2. Admin reviews documents → VERIFIED NGO badge
```

### 3.2 Claim flows

```
A) FREE CLAIM (donation channel — FSSAI 2019-compliant trail)
   - Vendor taps [Donate] at window close
   - Broadcast push/WhatsApp to verified NGOs within 5 km
   - First to claim wins → claim locks listing
   - NGO picks up by window end (self or volunteer)
   - NGO marks "distribution done" + optional beneficiary count
   - Platform issues donation receipt trail (vendor → NGO) → vendor CSR proof

B) BULK PURCHASE (subsidized)
   - NGO requests N boxes for a distribution drive (nominal fee)
   - Vendor confirms → single pickup window agreed
```

---

## 4. ADMIN / PLATFORM (web console — build this FIRST, see 12-ai-dev-guide)

### 4.1 Core queues

```
- Vendor verification queue: FSSAI no. check, photos, approve/reject+reason
- NGO verification queue: document checklist
- Listing audit: EXIF/geotag anomalies flagged (reused photo, wrong geo,
  photo timestamp older than listing)
- Dispute console: buyer report → order timeline (photos, stamps, QR log)
  → resolve: refund / vendor warning / suspension ladder:
     1st substantiated issue → warning + refund
     2nd → delist 7 days
     3rd → delist 30 days / ban
- No-show analytics: buyer strikes; vendor flake rate (listed but empty-handed)
```

### 4.2 Ops dashboard (Mumbai)

```
- Live map: active boxes per cluster (Andheri W / Vile Parle)
- Today: listed / sold / donated / wasted; sell-through % ⭐
- GMV, take-rate revenue, payment-fee spend
- GST collection ledger export (see 07)
- Payout batch status (weekly)
```

---

## 5. Master state machines (the heart of the flows)

```
LISTING:  draft → live → sold_out | expired → donated | wasted
ORDER:    reserved → paid → picked_up
                 ↘ hold_expired → back to live
                 ↘ no_show (at window_end + grace)
                 ↘ refunded (dispute)
PAYMENT:  created → authorized → captured → settled
                 ↘ failed → order void
                 ↘ refunded (full; partial not in v1)
```

Every transition is written to `AuditLog` (append-only) — this is what makes disputes and GST reconciliation resolvable.
