# 03 — Data Model

Database: **PostgreSQL 15 + PostGIS** (geo queries) via Supabase. All timestamps UTC; render IST in apps. All money in **paise** (integer) — never floats.

## 1. Entity relationship overview

```
User 1──N Restaurant (owner)          User 1──N NGO (contact)
Restaurant 1──N Listing               NGO 1──N Donation
Listing 1──1 PickupWindow             Listing 1──0..1 Donation
Listing 1──N Order                    Order 1──1 Payment
Order 1──0..1 Rating                  Order 1──0..N Incident
Restaurant 1──N Payout                Payout 1──N Order (settlement line)
User 1──N NotificationLog             everything → AuditLog
```

## 2. Tables & key fields

### users
| field | type | notes |
|---|---|---|
| id | uuid pk | |
| phone | text unique | E.164, identity = phone (India norm) |
| name | text | |
| role | enum | buyer / vendor_owner / ngo / admin |
| diet_pref | enum | veg (default) / nonveg / egg / jain / no_pref |
| trust_score | int | 0–100; starts 50; COD gating uses this |
| no_show_count | int | rolling 90-day |
| is_active | bool | |

### restaurants
| field | type | notes |
|---|---|---|
| id | uuid pk | |
| owner_user_id | fk users | |
| name, cuisine_tags | text / text[] | |
| fssai_license | text | **required**, format-validated |
| gstin | text nullable | |
| address, geo | text / geography(Point) | PostGIS, SRID 4326 |
| open_time, close_time | time | drives pickup-window defaults |
| food_type | enum | pure_veg / veg_nonveg / egg_ok |
| status | enum | pending / verified / suspended / rejected |
| rating_avg | numeric | denormalized, recomputed on rating insert |
| payout_upi / bank_details | text / jsonb | penny-drop verified flag |

### listings (the MysteryBox)
| field | type | notes |
|---|---|---|
| id | uuid pk | |
| restaurant_id | fk | |
| category | enum | veg / nonveg / egg / jain_friendly |
| qty_total, qty_left | int | qty_left decremented atomically on reserve |
| original_value_paise, price_paise | int | price ≥ 4900 (₹49 floor); price ≤ 50% of original (enforced in app + DB check) |
| contents_hint | text | "2 pav + 1 vada + 1 cookie" |
| photo_url | text | R2 object; EXIF/geotag extracted at upload |
| photo_geo, photo_taken_at | point / timestamptz | from EXIF; used by audit |
| prep_time, consume_by | timestamptz | **mandatory** — Plenti-standard freshness stamps |
| status | enum | draft / live / sold_out / expired / donated / wasted |
| donated_at, wasted_at | timestamptz nullable | |

### pickup_windows
| field | type | notes |
|---|---|---|
| id, listing_id | uuid / fk | 1:1 with listing in v1 |
| start_at, end_at | timestamptz | |
| grace_min | int | default 10 — monsoon buffer |

### orders
| field | type | notes |
|---|---|---|
| id | uuid pk | |
| buyer_id, listing_id | fk | |
| qty | int | v1: always 1 |
| amount_paise | int | |
| pay_method | enum | prepaid_upi / cod |
| status | enum | reserved / paid / picked_up / no_show / cancelled / refunded |
| qr_token | text unique | signed JWT, short-lived, shown as QR |
| pickup_otp | text | 6-digit fallback |
| reserved_at, paid_at, picked_up_at | timestamptz | |
| cod_collected | bool | vendor marks cash received |

### payments
| field | type | notes |
|---|---|---|
| id, order_id | fk | |
| gateway_ref | text | Razorpay payment_id |
| method | text | upi / card / cod |
| amount_paise | int | |
| platform_fee_paise | int | Razorpay 2%+GST record |
| gst_collected_paise | int | 5% of transaction value (ECO model) — see 07 |
| status | enum | created / authorized / captured / failed / refunded |
| refund_ref | text nullable | |

### payouts
| field | type | notes |
|---|---|---|
| id, restaurant_id | fk | |
| period_start, period_end | date | weekly cycle |
| gross_paise | int | sum of picked_up orders |
| commission_paise | int | ₹5/box × count (post free period) |
| gst_paise, net_paise | int | |
| status | enum | pending / processing / paid |
| batch_ref | text | Razorpay Route / NEFT ref |

### ngos
| field | type | notes |
|---|---|---|
| id, contact_user_id | fk | |
| name, reg_12a, reg_80g, darpan_id | text | verification checklist |
| geo | geography(point) | |
| verified, verified_at | bool / ts | admin action |

### donations
| field | type | notes |
|---|---|---|
| id, listing_id, ngo_id | fk | |
| claimed_at, picked_up_at | timestamptz | claim TTL 30 min else re-broadcast |
| beneficiary_count | int nullable | feeds vendor impact stats |
| receipt_no | text | donation trail for vendor CSR |

### ratings
| field | type | notes |
|---|---|---|
| id, order_id | fk | one per order |
| stars | int 1–5 | |
| tags | text[] | quantity / freshness / value / packing |
| comment | text | |

### incidents (report-a-problem)
| field | type | notes |
|---|---|---|
| id, order_id | fk | |
| type | enum | freshness / quantity / missing / hygiene / other |
| evidence_url | text | buyer photo |
| status | enum | open / resolved_refund / resolved_warning / dismissed |
| resolution_note, resolved_by | text / fk admin | |

### audit_logs (append-only)
| field | type |
|---|---|
| id, actor_id, actor_role | |
| entity, entity_id, action | text |
| old_value, new_value | jsonb |
| created_at | timestamptz |

### notifications_log
id · user_id · channel (push/sms/whatsapp) · template_key · payload jsonb · sent_at · status

## 3. Critical integrity rules (enforce in DB, not just app)

1. **No oversell:** `UPDATE listings SET qty_left = qty_left - 1 WHERE id = $1 AND qty_left > 0` — affected-rows check; a Redis hold TTL (10 min) covers the payment window.
2. **Price floor:** `CHECK (price_paise >= 4900)` and `CHECK (price_paise * 2 <= original_value_paise)`.
3. **Mystery freshness:** `CHECK (consume_by > prep_time)`; listing cannot go live without both + photo.
4. **One rating per order:** unique(order_id).
5. **Refund ≤ paid:** payments.status transition guarded.
6. **Immutability:** orders/payments never deleted; corrections via new rows + audit_logs.
