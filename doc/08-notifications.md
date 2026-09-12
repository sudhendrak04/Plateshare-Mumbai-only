# 08 — Notification Strategy

## 1. Channels

| Channel | Tool | Used for | Cost |
|---|---|---|---|
| Push | FCM + `flutter_local_notifications` | Buyer + vendor real-time alerts | Free |
| SMS | MSG91 (DLT-registered templates) | OTP, critical pickup alerts, fallback when push disabled | ~₹0.15–0.20/SMS |
| WhatsApp | Meta Cloud API | v1.1 — vendor daily digest, donation broadcasts, payout notices | Free (service window) |

Rule: **every push has an SMS fallback only for money-critical events** (pickup window, refund). Everything else is push-only to control SMS burn.

## 2. Trigger matrix

| # | Trigger | Audience | Channel | Timing | Copy (EN) |
|---|---|---|---|---|---|
| N1 | New live box within 2 km matching diet pref | Buyer | Push | Instant; throttle 1/user/hr | "🍞 {Vendor} just listed a {Veg} box — ₹{price} (worth ₹{orig}). Pickup {window}" |
| N2 | Order confirmed | Buyer | Push | Instant | "Reserved! Show your QR at {Vendor} between {start}–{end}" |
| N3 | Payment failed / hold expiring | Buyer | Push | T-8 min of hold | "Complete payment in {X} min or the box goes back" |
| N4 | Pickup window opened | Buyer | Push + SMS | At window start | "Pickup is open now at {Vendor}. Show your QR." |
| N5 | Window closing | Buyer | Push + SMS | T-15 min | "Your box waits till {end}. Don't miss it!" |
| N6 | No-show recorded | Buyer | Push | At sweep | "You missed pickup — box forfeited. Strike {n}/3 for COD." |
| N7 | Refund processed | Buyer | Push + SMS | On webhook | "₹{amt} refunded to source. 3–5 days to reflect." |
| N8 | New order received | Vendor | Push + WhatsApp | Instant | "New order: {qty}× {category} box, {prepaid/COD}. Pickup {window}" |
| N9 | Daily listing nudge | Vendor | Push + WhatsApp | 17:30 IST, only if nothing listed | "Any surplus today? 60 seconds to list: [Create Box]" |
| N10 | Donation broadcast | Verified NGOs | Push + WhatsApp | Instant on vendor donate | "{Vendor} has {n} boxes to donate. Claim within 30 min." |
| N11 | Donation claim won / lost | NGO / other NGOs | Push | Instant | won: "Claimed! Pick up by {time}" |
| N12 | Weekly payout | Vendor | Push + WhatsApp | On batch | "Payout ₹{net} processed for {week}" |
| N13 | Re-engagement | Dormant buyer (7d) | Push | 17:30 IST | "3 boxes live near you tonight 🥐" — opt-out respected |
| N14 | Vendor verification result | Vendor | Push + WhatsApp | On admin action | approved / rejected+reason |

## 3. Anti-fatigue rules (critical for retention)

1. Per-user notification budget: max **4 pushes/day**, N1 throttled to 1/hr.
2. Quiet hours: no pushes 23:30–09:00 IST (except N7 refunds).
3. Feed-based digest alternative: if user opened app that day, suppress N1/N13.
4. Every non-transactional push is individually disable-able in settings.
5. SMS only for: OTP, N4, N5, N7. Nothing else.

## 4. Deep-linking

All pushes deep-link to a specific screen: N1→listing, N2/N4/N5→order QR, N8→vendor order queue, N10→NGO claim list. Deep links carry `order_id`/`listing_id`; app resolves with a refresh on open (never trusts stale payload data).

## 5. Implementation notes

- Templates stored in a `notification_templates` table (key, channel, body, variables) — copy changes don't need app releases.
- Every send writes `notifications_log` (dedup + audit + fatigue accounting).
- Edge Function `send_notification(key, user_id, payload)` is the single entry point — no channel logic scattered in code.
