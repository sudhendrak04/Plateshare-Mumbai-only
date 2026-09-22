-- Stage 2 · seed (dev only; applied by `supabase db reset`)
-- 2 Mumbai clusters, 5 verified vendors, 3 buyers, 1 verified NGO, app config,
-- notification templates, blocked categories, 1 demo live listing.

begin;

-- app_config (backend_plan §12)
insert into public.app_config (key, value) values
  ('commission', '{"free_until": "2026-12-31", "per_box_paise": 500}'),
  ('cod_threshold', '70'),
  ('cod_min_orders', '2'),
  ('price_floor_paise', '4900'),
  ('max_discount', '0.5'),
  ('promo_first_box_paise', '4900'),
  ('grace_default_min', '10'),
  ('monsoon_grace_extra_min', '10')
on conflict (key) do nothing;

-- high-risk item blocklist (doc/09 §1 layer 4)
insert into public.blocked_categories (pattern, reason) values
  ('raw/undercooked seafood', 'Food-safety blocklist'),
  ('cut fruit', 'Food-safety blocklist'),
  ('cream/custard desserts', 'Food-safety blocklist'),
  ('day-old cooked food', 'Food-safety blocklist'),
  ('reheated from previous day', 'Food-safety blocklist')
on conflict (pattern) do nothing;

-- notification templates N1–N14 (doc/08 §2; copy refined in app stages)
insert into public.notification_templates (key, channels, body, variables) values
  ('N1_new_box_near_you', '{push}', '{vendor} just listed a {category} box — ₹{price} (worth ₹{orig}). Pickup {window}', '{vendor,category,price,orig,window}'),
  ('N2_order_confirmed', '{push}', 'Reserved! Show your QR at {vendor} between {start}–{end}', '{vendor,start,end}'),
  ('N3_hold_expiring', '{push}', 'Complete payment in {minutes} min or the box goes back', '{minutes}'),
  ('N4_window_opened', '{push,sms}', 'Pickup is open now at {vendor}. Show your QR.', '{vendor}'),
  ('N5_window_closing', '{push,sms}', 'Your box waits till {end}. Don''t miss it!', '{end}'),
  ('N6_no_show', '{push}', 'You missed pickup — box forfeited. Strike {n}/3 for COD.', '{n}'),
  ('N7_refund_processed', '{push,sms}', '₹{amt} refunded to source. 3–5 days to reflect.', '{amt}'),
  ('N8_new_order_vendor', '{push,whatsapp}', 'New order: {qty}× {category} box, {pay}. Pickup {window}', '{qty,category,pay,window}'),
  ('N9_daily_listing_nudge', '{push,whatsapp}', 'Any surplus today? 60 seconds to list: Create Box', '{}'),
  ('N10_donation_broadcast', '{push,whatsapp}', '{vendor} has {qty} boxes to donate. Claim within 30 min.', '{vendor,qty}'),
  ('N11_donation_claim_result', '{push}', 'Claimed! Pick up by {time}', '{time}'),
  ('N12_payout_processed', '{push,whatsapp}', 'Payout ₹{net} processed for {week}', '{net,week}'),
  ('N13_reengagement', '{push}', '{count} boxes live near you tonight', '{count}'),
  ('N14_vendor_verification', '{push,whatsapp}', 'Your outlet was {result}. {reason}', '{result,reason}')
on conflict (key) do nothing;

-- clusters (Andheri West, Vile Parle)
insert into public.clusters (name, center, radius_m) values
  ('Andheri West', extensions.st_setsrid(extensions.st_makepoint(72.8296, 19.1364), 4326), 2000),
  ('Vile Parle',    extensions.st_setsrid(extensions.st_makepoint(72.8495, 19.0968), 4326), 2000);

-- users (trigger creates profiles; role via server-side app metadata)
insert into auth.users (
  instance_id, id, aud, role, phone, phone_confirmed_at, email,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token,
  email_change, email_change_token_new,
  phone_change, phone_change_token
) values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', '+919900000001', now(), 'admin@plateshare.local', '{"provider":"email","providers":["email"],"role":"admin"}', '{"name":"PlateShare Admin"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000011', 'authenticated', 'authenticated', '+919900000011', now(), null, '{}', '{"name":"Andheri Bakery Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000012', 'authenticated', 'authenticated', '+919900000012', now(), null, '{}', '{"name":"Puff Corner Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000013', 'authenticated', 'authenticated', '+919900000013', now(), null, '{}', '{"name":"Cafe West Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000014', 'authenticated', 'authenticated', '+919900000014', now(), null, '{}', '{"name":"Parle Sweets Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000015', 'authenticated', 'authenticated', '+919900000015', now(), null, '{}', '{"name":"Parle Bakes Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 'authenticated', 'authenticated', '+919900000021', now(), null, '{}', '{"name":"Test Buyer One"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 'authenticated', 'authenticated', '+919900000022', now(), null, '{}', '{"name":"Test Buyer Two"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000023', 'authenticated', 'authenticated', '+919900000023', now(), null, '{}', '{"name":"Test Buyer Three"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000031', 'authenticated', 'authenticated', '+919900000031', now(), null, '{}', '{"name":"NGO Contact Person"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000016', 'authenticated', 'authenticated', '+919900000016', now(), null, '{}', '{"name":"Ghatkopar Kitchen Owner"}', now(), now(), '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000032', 'authenticated', 'authenticated', '+919900000032', now(), null, '{}', '{"name":"NGO Contact Two"}', now(), now(), '', '', '', '', '', '');

-- restaurants (5 verified vendors across both clusters)
insert into public.restaurants
  (id, owner_user_id, name, cuisine_tags, fssai_license, fssai_expiry_date, address, geo, food_type, status, payout_upi)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000011', 'Andheri Bakery House',   '{bakery,snacks}',  '11111111111111', now() + interval '300 days', 'Shop 4, Lokhandwala, Andheri West', extensions.st_setsrid(extensions.st_makepoint(72.8300, 19.1368), 4326), 'egg_ok',     'verified', 'owner1@upi'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000012', 'Parsi Puff Corner',      '{bakery,veg}',     '22222222222222', now() + interval '300 days', 'Four Bungalows, Andheri West', extensions.st_setsrid(extensions.st_makepoint(72.8330, 19.1320), 4326), 'pure_veg',   'verified', 'owner2@upi'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000013', 'Cafe Westside Andheri',  '{cafe,sandwiches}','33333333333333', now() + interval '300 days', 'Veera Desai Road, Andheri West', extensions.st_setsrid(extensions.st_makepoint(72.8390, 19.1300), 4326), 'veg_nonveg', 'verified', 'owner3@upi'),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000014', 'Parle Snacks & Sweets',  '{sweets,farsan}',  '44444444444444', now() + interval '300 days', 'Vile Parle East, Near Station', extensions.st_setsrid(extensions.st_makepoint(72.8510, 19.0975), 4326), 'pure_veg',   'verified', 'owner4@upi'),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000015', 'Parle Bakes & Buns',     '{bakery,bread}',   '55555555555555', now() + interval '300 days', 'Vile Parle West, SV Road', extensions.st_setsrid(extensions.st_makepoint(72.8480, 19.0990), 4326), 'egg_ok',     'verified', 'owner5@upi');

-- ngo (verified, near Andheri)
insert into public.ngos (id, contact_user_id, name, reg_12a, reg_80g, darpan_id, geo, verified, verified_at)
values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031', 'Mumbai Roti Seva Trust', 'MUM/12A/2019/0042', 'MUM/80G/0042', 'MH/2026/0123456', extensions.st_setsrid(extensions.st_makepoint(72.8350, 19.1330), 4326), true, now());

-- demo live listing (bakery veg box, window now −15m … +45m)
insert into public.listings
  (id, restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
   contents_hint, photo_url, photo_geo, photo_taken_at, prep_time, consume_by, closes_at, status)
values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'veg', 5, 5, 19900, 9900,
   '3 puffs + 2 buns + 1 cookie pack', 'seed://photos/andheri-bakery-house/box-1.jpg',
   extensions.st_setsrid(extensions.st_makepoint(72.8300, 19.1368), 4326),
   now() - interval '10 minutes',
   now() - interval '25 minutes', now() + interval '3 hours', now() + interval '45 minutes', 'live');

insert into public.pickup_windows (listing_id, start_at, end_at, grace_min)
values ('30000000-0000-0000-0000-000000000001', now() - interval '15 minutes', now() + interval '45 minutes', 10);

-- draft listing (no photo — blocked from going live by the DB trigger)
insert into public.listings
  (id, restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
   contents_hint, prep_time, consume_by, closes_at, status)
values
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'veg', 3, 3, 14900, 6900,
   '2 sandwiches + 1 beverage', now() - interval '25 minutes', now() + interval '3 hours', now() + interval '45 minutes', 'draft');

-- audit trail for seeded state changes
insert into public.audit_logs (actor_id, actor_role, entity, entity_id, action, new_value) values
  ('00000000-0000-0000-0000-000000000001', 'admin', 'restaurants', '10000000-0000-0000-0000-000000000001', 'verified', '{"status":"verified"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'restaurants', '10000000-0000-0000-0000-000000000002', 'verified', '{"status":"verified"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'restaurants', '10000000-0000-0000-0000-000000000003', 'verified', '{"status":"verified"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'restaurants', '10000000-0000-0000-0000-000000000004', 'verified', '{"status":"verified"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'restaurants', '10000000-0000-0000-0000-000000000005', 'verified', '{"status":"verified"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'ngos', '20000000-0000-0000-0000-000000000001', 'verified', '{"verified":true}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'listings', '30000000-0000-0000-0000-000000000001', 'published', '{"status":"live"}');

-- ───────── Stage 3 additions: orders in every state, ratings, incidents, donations ─────────

-- buyer 022 = COD-eligible (trust 80)
update public.profiles set trust_score = 80 where id = '00000000-0000-0000-0000-000000000022';

-- two historical picked_up COD orders for buyer 022 (listing 1; qty 5 → 3 left)
update public.listings set qty_left = 3 where id = '30000000-0000-0000-0000-000000000001';
insert into public.orders (id, buyer_id, listing_id, qty, amount_paise, pay_method, status,
                           qr_token, pickup_otp, picked_up_at, cod_collected)
values
  ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000022',
   '30000000-0000-0000-0000-000000000001', 1, 9900, 'cod', 'picked_up',
   'seed-qr-hist-1', '111111', now() - interval '1 day', true),
  ('40000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000022',
   '30000000-0000-0000-0000-000000000001', 1, 9900, 'cod', 'picked_up',
   'seed-qr-hist-2', '222222', now() - interval '1 day', true);
insert into public.payments (order_id, method, amount_paise, status) values
  ('40000000-0000-0000-0000-000000000001', 'cod', 9900, 'captured'),
  ('40000000-0000-0000-0000-000000000002', 'cod', 9900, 'captured');

-- ratings on those orders (triggers recompute restaurant rating_avg)
insert into public.ratings (order_id, stars, tags, comment) values
  ('40000000-0000-0000-0000-000000000001', 5, '{quantity,value}', 'Good quantity'),
  ('40000000-0000-0000-0000-000000000002', 4, '{freshness}', 'Fresh puffs');

-- listing 3: expired yesterday (vendor 2) — orders: picked_up, no_show, cancelled, refunded
insert into public.listings
  (id, restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
   contents_hint, photo_url, photo_geo, photo_taken_at, prep_time, consume_by, closes_at, status)
values
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'veg',
   6, 2, 15900, 6900, '4 puffs + 2 buns', 'seed://photos/puff-corner/box-3.jpg',
   extensions.st_setsrid(extensions.st_makepoint(72.8330, 19.1320), 4326),
   now() - interval '26 hours', now() - interval '27 hours',
   now() + interval '3 hours', now() - interval '1 hour', 'expired');
insert into public.pickup_windows (listing_id, start_at, end_at, grace_min)
values ('30000000-0000-0000-0000-000000000003', now() - interval '2 hours', now() - interval '1 hour', 10);

insert into public.orders (id, buyer_id, listing_id, qty, amount_paise, pay_method, status,
                           qr_token, pickup_otp, picked_up_at, cod_collected) values
  ('40000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000021',
   '30000000-0000-0000-0000-000000000003', 1, 6900, 'prepaid_upi', 'picked_up',
   'seed-qr-hist-3', '333333', now() - interval '1 hour - 30 minutes', false),
  ('40000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000023',
   '30000000-0000-0000-0000-000000000003', 1, 6900, 'prepaid_upi', 'no_show',
   'seed-qr-hist-4', '444444', null, false),
  ('40000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000021',
   '30000000-0000-0000-0000-000000000003', 1, 6900, 'prepaid_upi', 'cancelled',
   'seed-qr-hist-5', '555555', null, false),
  ('40000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000021',
   '30000000-0000-0000-0000-000000000003', 1, 6900, 'prepaid_upi', 'refunded',
   'seed-qr-hist-6', '666666', null, false);
insert into public.payments (order_id, gateway_ref, razorpay_order_id, method, amount_paise, status, refund_ref) values
  ('40000000-0000-0000-0000-000000000003', 'pay_seed3', 'order_seed3', 'upi', 6900, 'captured', null),
  ('40000000-0000-0000-0000-000000000004', 'pay_seed4', 'order_seed4', 'upi', 6900, 'captured', null),
  ('40000000-0000-0000-0000-000000000006', 'pay_seed6', 'order_seed6', 'upi', 6900, 'refunded', 'rfnd_seed6');
update public.profiles set no_show_count = 1, trust_score = 30 where id = '00000000-0000-0000-0000-000000000023';

-- incidents: one open (freshness), one resolved (refund)
insert into public.incidents (id, order_id, type, evidence_url, status, resolution_note, resolved_by) values
  ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000003', 'freshness', 'seed://evidence/photo-1.jpg', 'open', null, null),
  ('50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000006', 'quantity', null, 'resolved_refund', 'Refunded in full', '00000000-0000-0000-0000-000000000001');

-- listing 4: donated & completed (vendor 4) — donation trail demo
insert into public.listings
  (id, restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
   contents_hint, photo_url, photo_geo, photo_taken_at, prep_time, consume_by, closes_at, status, donated_at)
values
  ('30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'veg',
   4, 4, 12900, 5900, '6 farsan packs', 'seed://photos/parle-sweets/box-4.jpg',
   extensions.st_setsrid(extensions.st_makepoint(72.8510, 19.0975), 4326),
   now() - interval '26 hours', now() - interval '27 hours',
   now() + interval '3 hours', now() - interval '2 hours', 'donated', now() - interval '1 hour');
insert into public.pickup_windows (listing_id, start_at, end_at, grace_min)
values ('30000000-0000-0000-0000-000000000004', now() - interval '2 hours', now() - interval '1 hour', 10);
insert into public.donations (id, listing_id, ngo_id, claimed_at, picked_up_at, claim_expires_at,
                              beneficiary_count, receipt_no, broadcast_count)
values ('60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000004',
        '20000000-0000-0000-0000-000000000001', now() - interval '50 minutes', now() - interval '20 minutes',
        null, 12, 'PS-DON-2026-0001', 1);

-- listing 5: donated, unclaimed (NGO portal demo)
insert into public.listings
  (id, restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
   contents_hint, photo_url, photo_geo, photo_taken_at, prep_time, consume_by, closes_at, status, donated_at)
values
  ('30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005', 'egg',
   4, 4, 13900, 6900, '4 pav + 4 bhurji packs', 'seed://photos/parle-bakes/box-5.jpg',
   extensions.st_setsrid(extensions.st_makepoint(72.8480, 19.0990), 4326),
   now() - interval '26 hours', now() - interval '27 hours',
   now() + interval '3 hours', now() - interval '30 minutes', 'donated', now() - interval '25 minutes');
insert into public.pickup_windows (listing_id, start_at, end_at, grace_min)
values ('30000000-0000-0000-0000-000000000005', now() - interval '2 hours', now() - interval '1 hour', 10);
insert into public.donations (id, listing_id, broadcast_count)
values ('60000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000005', 1);

-- dev login for the admin console (email+password works locally without SMS provider)
-- bcrypt cost 10 to match GoTrue's own hashing
update auth.users
set encrypted_password = extensions.crypt('plateshare-dev', extensions.gen_salt('bf', 10)),
    email_confirmed_at = now()
where id = '00000000-0000-0000-0000-000000000001';

-- dev login for the NGO portal
update auth.users
set email = 'ngo@plateshare.local',
    encrypted_password = extensions.crypt('plateshare-ngo', extensions.gen_salt('bf', 10)),
    email_confirmed_at = now()
where id = '00000000-0000-0000-0000-000000000031';

-- password sign-in needs an email identity row (SQL seed must add it manually).
-- Match GoTrue's own shape: provider_id = user uuid, identity_data with sub/email/verified.
insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'email',
    '{"sub":"00000000-0000-0000-0000-000000000001","email":"admin@plateshare.local","email_verified":true,"phone_verified":false}',
    now(), now(), now()),
  ('00000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000031', 'email',
    '{"sub":"00000000-0000-0000-0000-000000000031","email":"ngo@plateshare.local","email_verified":true,"phone_verified":false}',
    now(), now(), now())
on conflict (provider_id, provider) do nothing;

-- restaurant 6: PENDING (queue demo) + NGO 2: unverified (NGO queue demo)
insert into public.restaurants (id, owner_user_id, name, cuisine_tags, fssai_license, fssai_expiry_date, address, geo, food_type, status)
values ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000016', 'Ghatkopar Kitchen Test', '{cafe}', '66666666666666', now() + interval '300 days', 'Andheri East, Test Lane', extensions.st_setsrid(extensions.st_makepoint(72.8560, 19.1100), 4326), 'veg_nonveg', 'pending');
insert into public.ngos (id, contact_user_id, name, reg_12a, reg_80g, darpan_id, geo, verified)
values ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000032', 'Seva Anna Foundation', 'MUM/12A/2020/0099', 'MUM/80G/0099', 'MH/2026/0999999', extensions.st_setsrid(extensions.st_makepoint(72.8400, 19.1200), 4326), false);

-- audit rows for stage-3 seed states
insert into public.audit_logs (actor_id, actor_role, entity, entity_id, action, old_value, new_value) values
  ('00000000-0000-0000-0000-000000000023', 'buyer', 'orders', '40000000-0000-0000-0000-000000000004', 'no_show', '{"status":"paid"}', '{"status":"no_show"}'),
  ('00000000-0000-0000-0000-000000000001', 'admin', 'incidents', '50000000-0000-0000-0000-000000000002', 'resolved_refund', '{"status":"open"}', '{"action":"refund"}'),
  ('00000000-0000-0000-0000-000000000014', 'vendor_owner', 'listings', '30000000-0000-0000-0000-000000000004', 'donated', '{"status":"expired"}', '{"status":"donated"}');
