# 05 — API Specification

Convention: Supabase client SDK for CRUD where RLS protects it; **Postgres RPCs** for anything transactional; **Edge Functions** for anything touching external services. All money in paise. All responses JSON.

Auth: Supabase phone-OTP JWT. Roles resolved from `users.role` via JWT claims + RLS policies.

## 1. Auth

| Endpoint | Method | Notes |
|---|---|---|
| `auth.signInWithOtp({phone})` | SDK | Supabase native phone OTP (MSG91 provider) |
| `auth.verifyOtp({phone, token})` | SDK | returns JWT; profile row auto-created by DB trigger |
| `POST /rpc/update_profile` | RPC | name, diet_pref |

## 2. Buyer

| Endpoint | Method | Body | Returns |
|---|---|---|---|
| `POST /rpc/nearby_listings` | RPC | `{lat, lng, radius_m?, category?, max_price_paise?, before_ts?}` | live listings + vendor info + distance_m |
| `GET /listings/{id}` | SDK/RLS | — | detail (adds vendor rating, stamps) |
| `POST /rpc/reserve_order` | RPC | `{listing_id, pay_method}` | `{order_id, expires_at, razorpay_order_id?}` — atomic qty decrement + hold |
| `POST /fn/create_razorpay_order` | Edge | `{order_id}` | gateway order (prepaid only) |
| `POST /fn/verify_and_confirm` | Edge | internal (webhook) | marks paid |
| `POST /fn/create_cod_order` | Edge | `{order_id}` | trust-score check → confirms COD |
| `POST /rpc/cancel_order` | RPC | `{order_id}` | only while `reserved`; releases hold |
| `GET /orders?buyer=me` | SDK/RLS | — | history + QR token for active |
| `POST /rpc/rate_order` | RPC | `{order_id, stars, tags[], comment?}` | after pickup |
| `POST /fn/report_incident` | Edge | `{order_id, type, photo}` | opens incident, notifies admin |

## 3. Vendor

| Endpoint | Method | Body | Returns |
|---|---|---|---|
| `POST /rpc/register_restaurant` | RPC | profile + FSSAI + geo | status=pending |
| `POST /fn/upload_listing_photo` | Edge | multipart | validates EXIF/geotag → `{photo_url, taken_at}` |
| `POST /rpc/create_listing` | RPC | `{category, qty, original_value, price, contents_hint, photo_url, prep_time, consume_by, window{start,end,grace}}` | listing (status=live) — server re-validates floor/discount |
| `POST /rpc/update_listing_qty` | RPC | `{listing_id, qty_delta}` | guarded: qty_left ≥ sold_count |
| `POST /rpc/mark_sold_out` | RPC | `{listing_id}` | |
| `GET /rpc/vendor_orders_today` | RPC | — | live queue |
| `POST /rpc/confirm_pickup` | RPC | `{qr_token}` or `{otp}` | order → picked_up; COD → cod_collected=true |
| `POST /rpc/donate_leftover` | RPC | `{listing_id}` | expired listing → donation broadcast |
| `GET /rpc/vendor_stats` | RPC | `{date_range}` | sold/donated/wasted, revenue, impact |
| `GET /rpc/vendor_payouts` | RPC | — | weekly batches |

## 4. NGO (web console)

| Endpoint | Method | Notes |
|---|---|---|
| `POST /fn/ngo_apply` | Edge | org details + doc URLs → admin queue |
| `GET /rpc/ngo_open_donations` | RPC | live donation broadcasts within 5 km |
| `POST /rpc/claim_donation` | RPC | atomic claim; TTL 30 min |
| `POST /rpc/confirm_donation_pickup` | RPC | picked_up_at |
| `POST /rpc/report_beneficiaries` | RPC | `{donation_id, count}` |

## 5. Admin (web console)

| Endpoint | Method | Notes |
|---|---|---|
| `GET /rpc/admin_queue_vendors` | RPC | pending list |
| `POST /rpc/admin_verify_vendor` | RPC | `{restaurant_id, approve?, reason?}` |
| `POST /rpc/admin_verify_ngo` | RPC | same pattern |
| `GET /rpc/admin_listing_audit` | RPC | EXIF/geotag anomaly flags |
| `GET /rpc/admin_incidents` | RPC | open disputes |
| `POST /rpc/admin_resolve_incident` | RPC | `{incident_id, action: refund|warning|delist7|delist30|ban, note}` — triggers Razorpay refund via Edge Fn |
| `GET /rpc/admin_ops_dashboard` | RPC | per-cluster: listed/sold/donated/wasted, sell-through %, GMV |
| `GET /rpc/admin_gst_ledger` | RPC | month export: transaction GST collected (ECO model) |
| `POST /fn/run_payout_batch` | Edge | weekly; prepares Route transfers |

## 6. Webhooks (external → us)

| Source | Path | Handling |
|---|---|---|
| Razorpay | `POST /fn/razorpay_webhook` | verify HMAC signature → payment.captured / refund.processed / payout.processed → update rows + Realtime emit |
| MSG91 DLR | optional v1.1 | delivery receipts |

## 7. Error contract

```json
{ "error": { "code": "QTY_EXHAUSTED", "message": "This box just sold out", "retryable": false } }
```

Standard codes: `QTY_EXHAUSTED`, `HOLD_EXPIRED`, `TRUST_TOO_LOW_FOR_COD`, `WINDOW_CLOSED`, `PRICE_FLOOR`, `FSSAI_INVALID`, `PHOTO_EXIF_INVALID`, `UNAUTHORIZED_ROLE`.

All RPCs are wrapped in transactions; every state transition writes `audit_logs`.
