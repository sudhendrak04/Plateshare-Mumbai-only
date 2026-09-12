# 04 — System Architecture

## 1. Component map

```
┌──────────────┐   ┌──────────────┐   ┌─────────────────────────┐
│ Buyer App    │   │ Vendor App   │   │ Admin + NGO Web Console │
│ (Flutter,    │   │ (Flutter,    │   │ (Next.js on Vercel)     │
│  Android 1st)│   │  Android 1st)│   │                         │
└──────┬───────┘   └──────┬───────┘   └───────────┬─────────────┘
       │                  │                       │
       └──────────────────┴───────────┬───────────┘
                                      │ HTTPS + JWT (Supabase Auth)
                        ┌─────────────▼─────────────┐
                        │      SUPABASE             │
                        │  Postgres 15 + PostGIS    │
                        │  Row-Level Security       │
                        │  Edge Functions (Deno TS) │
                        │  Auth (phone OTP)         │
                        │  Realtime (order events)  │
                        │  Storage → R2/S3 proxy    │
                        └──┬─────────┬──────────┬───┘
                           │         │          │
              ┌────────────▼──┐  ┌───▼────────┐ ┌▼─────────────────┐
              │ Scheduled Jobs│  │ Razorpay   │ │ Messaging        │
              │ (pg_cron /    │  │ (UPI/cards │ │ FCM push         │
              │  Supabase     │  │  + Route   │ │ MSG91 SMS/OTP    │
              │  cron hooks)  │  │  payouts)  │ │ WhatsApp BAPI    │
              └───────────────┘  └────────────┘ │ (vendor alerts)  │
                                                └──────────────────┘
```

**Design principle for a 2-person AI-coded team:** one managed platform (Supabase) instead of self-run API servers + Redis + cron workers. Business logic that must be server-trusted (order state transitions, inventory decrement, payout math, no-show sweeps) lives in **Postgres functions (RPC) + Edge Functions**, called from the apps. This removes ~70% of the infrastructure a traditional backend would need, while staying scalable: Supabase Postgres scales to serious traffic before any migration is needed.

## 2. Responsibilities by layer

| Layer | Owns | Must NOT own |
|---|---|---|
| **Buyer/Vendor apps (Flutter)** | UI, camera capture (EXIF), QR display/scan, maps | Pricing math, inventory truth, payment verification |
| **Postgres (RLS + RPC)** | Inventory decrement, order state machine, price-floor checks, audit log | Push sending (side effects → Edge Functions) |
| **Edge Functions** | Razorpay webhook handling, notification fan-out, donation broadcast, payout batch prep, EXIF validation | Long-running work (none exists in v1) |
| **Scheduled jobs** | Listing expiry, T-15 window alerts, no-show sweep, donation claim TTL, weekly payout batch | — |
| **Razorpay** | Payment capture, Route splits to vendor accounts, refunds | — |

## 3. Key sequence: Reserve → Pay → Pick up (prepaid)

```
Buyer App            Supabase (RPC)              Razorpay
   │  reserve(listing)     │                          │
   ├──────────────────────>│ tx: qty_left-1 (guard),  │
   │                       │ order=reserved, Redisless│
   │                       │ hold via orders.expires_at│
   │<── order_id + razorpay_order params (Edge Fn)───│
   │  pay (UPI) ─────────────────────────────────────>│
   │                       │<── webhook: payment.captured
   │                       │ verify signature,        │
   │                       │ order=paid, payment row  │
   │<── realtime event: order paid ──────────────────│
   │  [T-15 push: window closing]                     │
   │  show QR at vendor ──> vendor scans ──> RPC      │
   │                       │ verify qr_token + window,│
   │                       │ order=picked_up          │
   │                       │ (COD: vendor marks cod_collected)
```

## 4. Scheduled jobs (pg_cron, every minute for the sweep)

| Job | Schedule | Action |
|---|---|---|
| `sweep_holds` | every min | orders stuck `reserved` past expires_at → release qty, void order |
| `sweep_listings` | every min | past `pickup_window.end_at + grace` → live listings → expired; paid-unpicked orders → `no_show` + buyer strike + vendor notification |
| `donation_ttl` | every min | unclaimed donations after 30 min → re-broadcast once → then mark `wasted` |
| `window_alerts` | every min | T-15 min before window end → push+SMS to unpaid-in-window buyers & picked-up pending confirmations |
| `weekly_payouts` | Mon 02:00 IST | aggregate picked_up orders per vendor → payout batch (Edge Fn → Razorpay Route) |
| `daily_digest` | 18:00 IST | vendor WhatsApp: "yesterday: X sold, Y donated"; admin ops summary |

## 5. Geolocation & discovery

- `restaurants.geo` = PostGIS geography point; discovery RPC:
  ```sql
  SELECT l.*, r.name, ST_Distance(r.geo, $buyer_point) AS dist_m
  FROM listings l JOIN restaurants r ON r.id = l.restaurant_id
  WHERE l.status = 'live'
    AND r.status = 'verified'
    AND ST_DWithin(r.geo, $buyer_point, $radius_m)   -- default 2000
    AND ($category IS NULL OR l.category = $category)
  ORDER BY l.pickup_end ASC NULLS LAST, dist_m ASC
  LIMIT 50;
  ```
- Buyer location: device GPS (foreground only); store only city/area coarsely for analytics.
- Map rendering: Google Maps Flutter plugin (v1); MapmyIndia swap possible later.
- Mumbai station-clusters: seed `clusters` table (name, center point, radius) to power the ops dashboard and "cluster full" gating during launch.

## 6. Real-time inventory expiry

- Listings are **time-boxed by construction**: `pickup_window.end_at` is the expiry. No background "listing lifetime" logic needed beyond the sweep.
- Buyer feed shows countdown from client clock vs. `end_at` (server time sync endpoint for drift > 2 min).
- `qty_left` is the single source of truth; feed reads it directly; sold-out flip is a DB status update → Realtime broadcast to subscribed clients.

## 7. File storage

- Listing photos: Cloudflare R2 (zero egress) via Supabase Storage-compatible S3 API or Supabase Storage itself in v1 (simpler; migrate later if cost demands).
- Upload path: app captures JPEG → Edge Function validates EXIF (taken_at within 15 min, geotag within 500 m of restaurant) → stores original.

## 8. Environments & CI

| Env | Purpose | Notes |
|---|---|---|
| `dev` | local Supabase CLI + Android emulator | free tier |
| `staging` | Supabase project #2 + Razorpay **test** keys | demo to vendors |
| `prod` | Supabase project #3 + live keys | Mumbai launch |

- GitHub Actions: on PR → `flutter analyze` + `dart test`; on merge to main → build APK artifact. (AI can generate this pipeline; it is 30 lines.)
- Secrets: Supabase dashboard + GitHub encrypted secrets. **Never in repo.**

## 9. Scaling path (when needed, not before)

1. Move heavy RPCs to dedicated NestJS/FastAPI service behind same Postgres.
2. Add Redis for hot feed caching if feed p95 > 300 ms (unlikely before 10k DAU).
3. Add read replica for analytics (Metabase).
4. Multi-city = data-level `city_id` column added **now** (cheap foresight, zero complexity).
