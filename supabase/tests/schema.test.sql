-- Stage 2 · schema pgTAP tests (constraint, trigger, RLS checks)
begin;
select plan(10);

-- helper id
create temp table _ids as
  select '10000000-0000-0000-0000-000000000001'::uuid as restaurant_id,
         '00000000-0000-0000-0000-000000000021'::uuid as buyer_id,
         '30000000-0000-0000-0000-000000000001'::uuid as live_listing_id;

-- 1. price below floor (₹30) rejected
select throws_ok(
  format(
    $q$insert into public.listings
      (restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
       photo_url, photo_taken_at, photo_geo, prep_time, consume_by, closes_at, status)
    values (%L, 'veg', 5, 5, 10000, 3000, 'seed://x', now(),
            (select center from public.clusters limit 1), now(), now() + interval '2h', now() + interval '1h', 'live')$q$,
    (select restaurant_id from _ids)
  ),
  '23514', null, 'price below ₹49 floor rejected'
);

-- 2. discount ceiling violated (price = original, i.e. 0% off) rejected
select throws_ok(
  format(
    $q$insert into public.listings
      (restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
       photo_url, photo_taken_at, photo_geo, prep_time, consume_by, closes_at, status)
    values (%L, 'veg', 5, 5, 10000, 10000, 'seed://x', now(),
            (select center from public.clusters limit 1), now(), now() + interval '2h', now() + interval '1h', 'live')$q$,
    (select restaurant_id from _ids)
  ),
  '23514', null, 'price must be at most 50% of original value'
);

-- 3. consume_by before prep_time rejected
select throws_ok(
  format(
    $q$insert into public.listings
      (restaurant_id, category, qty_total, qty_left, original_value_paise, price_paise,
       photo_url, photo_taken_at, photo_geo, prep_time, consume_by, closes_at, status)
    values (%L, 'veg', 5, 5, 10000, 4900, 'seed://x', now(),
            (select center from public.clusters limit 1),
            now() + interval '2h', now(), now() + interval '1h', 'live')$q$,
    (select restaurant_id from _ids)
  ),
  '23514', null, 'consume_by must be after prep_time'
);

-- 4. live listing without photo rejected (trigger)
select throws_ok(
  format(
    $q$update public.listings set status = 'live' where id = '30000000-0000-0000-0000-000000000002'$q$
  ),
  '23514', null, 'live listing without photo rejected'
);

-- 5. audit_logs append-only: update rejected
select throws_ok(
  $q$update public.audit_logs set action = 'tampered' where action = 'published'$q$,
  '23514', null, 'audit_logs cannot be updated'
);

-- 6. audit_logs append-only: delete rejected
select throws_ok(
  $q$delete from public.audit_logs where action = 'published'$q$,
  '23514', null, 'audit_logs cannot be deleted'
);

-- 7. anon role sees zero orders (RLS default-deny)
set local role anon;
select is(
  (select count(*) from public.orders),
  0::bigint,
  'anon cannot see any orders'
);
reset role;

-- 8. authenticated buyer sees exactly own profile via RLS
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}';
select is(
  (select count(*) from public.profiles),
  1::bigint,
  'authenticated buyer sees only own profile'
);
reset role;

-- 9. pickup window sync: creating a window updates listings.closes_at
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000011';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000011","role":"authenticated"}';
select lives_ok(
  format(
    $q$update public.pickup_windows set end_at = now() + interval '50 minutes'
    where listing_id = '30000000-0000-0000-0000-000000000001'$q$
  ),
  'vendor can move their pickup window'
);
select is(
  (select (closes_at > now() + interval '40 minutes')::text from public.listings where id = '30000000-0000-0000-0000-000000000001'),
  'true',
  'closes_at denormalized from window end'
);
reset role;

select * from finish();
rollback;
