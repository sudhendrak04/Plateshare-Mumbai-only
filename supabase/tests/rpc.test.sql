-- Stage 3 · RPC pgTAP tests — 🔴 money paths + state machine (doc/12 §2 tests-first)
begin;
select plan(25);

-- ── 1. reserve decrements atomically + order created ──
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}';
select lives_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''prepaid_upi'')',
  'buyer1 reserves a prepaid box'
);
reset role;
select is(
  (select qty_left from public.listings where id = '30000000-0000-0000-0000-000000000001'),
  2::int, -- seed had 3 (after 2 historical); reserve → 2
  'reserve decremented qty_left'
);
select is(
  (select count(*) from public.orders where buyer_id = '00000000-0000-0000-0000-000000000021' and status = 'reserved'),
  1::bigint, 'reserved order row created'
);
select is(
  (select (qr_token is not null and pickup_otp is not null)::text
   from public.orders where status = 'reserved' limit 1),
  'true', 'order has QR token + OTP'
);

-- ── 2. oversell guard on the last box ──
update public.listings set qty_left = 1 where id = '30000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}';
select lives_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''prepaid_upi'')',
  'last box reservable'
);
select throws_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''prepaid_upi'')',
  'P0001', null, 'second reserve on the last box rejected (no oversell)'
);
reset role;

-- ── 3. hold expiry → sweep releases qty ──
update public.orders set expires_at = now() - interval '1 minute'
where buyer_id = '00000000-0000-0000-0000-000000000021' and status = 'reserved';
select is(
  (select public.sweep_holds()),
  2::int, -- both reserved orders from tests 1+2 expired
  'sweep_holds released expired holds'
);
select is(
  (select status from public.orders
   where buyer_id = '00000000-0000-0000-0000-000000000021' and status = 'cancelled'
   limit 1),
  'cancelled', 'expired holds are cancelled'
);

-- ── 4. COD gate ──
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}';
select throws_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''cod'')',
  'P0001', null, 'low-trust buyer blocked from COD'
);
reset role;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000022';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000022","role":"authenticated"}';
select lives_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''cod'')',
  'COD-eligible buyer can reserve COD'
);
reset role;

-- ── 5. no-show sweep: window passes → strike + trust drop ──
update public.pickup_windows
set start_at = now() - interval '80 minutes',
    end_at = now() - interval '20 minutes'
where listing_id = '30000000-0000-0000-0000-000000000001';
select is(
  (select (public.sweep_listings() > 0)::text),
  'true', 'sweep_listings expired the passed window'
);
select is(
  (select status from public.orders
   where buyer_id = '00000000-0000-0000-0000-000000000022'
     and pay_method = 'cod' and status = 'no_show'
   limit 1),
  'no_show', 'unpicked COD order became no_show'
);
select is(
  (select no_show_count from public.profiles where id = '00000000-0000-0000-0000-000000000022'),
  1::int, 'no-show strike incremented'
);
select is(
  (select trust_score from public.profiles where id = '00000000-0000-0000-0000-000000000022'),
  60::int, -- 80 − 20
  'trust score dropped 20 on no-show'
);

-- ── 6. rating flow: only picked_up, unique per order ──
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000021';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000021","role":"authenticated"}';
select lives_ok(
  'select public.rate_order(''40000000-0000-0000-0000-000000000003''::uuid, 5, ''{value}'')',
  'buyer can rate a picked_up order'
);
select throws_ok(
  'select public.rate_order(''40000000-0000-0000-0000-000000000003''::uuid, 5, ''{}'')',
  'P0001', null, 'second rating on same order rejected'
);
select throws_ok(
  'select public.rate_order(''40000000-0000-0000-0000-000000000004''::uuid, 5, ''{}'')',
  'P0001', null, 'rating a no_show order rejected'
);
reset role;

-- ── 7. donation claim: single winner ──
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000031';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000031","role":"authenticated"}';
select lives_ok(
  'select public.claim_donation(''60000000-0000-0000-0000-000000000002''::uuid)',
  'NGO claims an open donation'
);
select throws_ok(
  'select public.claim_donation(''60000000-0000-0000-0000-000000000002''::uuid)',
  'P0001', null, 'second claim on same donation rejected'
);
select lives_ok(
  'select public.confirm_donation_pickup(''60000000-0000-0000-0000-000000000002''::uuid)',
  'NGO confirms donation pickup'
);
select lives_ok(
  'select public.report_beneficiaries(''60000000-0000-0000-0000-000000000002''::uuid, 25)',
  'NGO reports beneficiary count'
);
reset role;

-- ── 8. smoke: reserve → pay (simulated) → confirm via QR → rate → rating recompute ──
update public.pickup_windows
set end_at = now() + interval '45 minutes'
where listing_id = '30000000-0000-0000-0000-000000000001';
update public.listings
set status = 'live', qty_left = 5, qty_total = 5
where id = '30000000-0000-0000-0000-000000000001';

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000022';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000022","role":"authenticated"}';
select lives_ok(
  'select * from public.reserve_order(''30000000-0000-0000-0000-000000000001''::uuid, ''prepaid_upi'')',
  'smoke: buyer2 reserves'
);
reset role;

update public.orders
set status = 'paid', paid_at = now()
where buyer_id = '00000000-0000-0000-0000-000000000022' and status = 'reserved';

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000011';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000011","role":"authenticated"}';
select lives_ok(
  'select public.confirm_pickup(o.id, o.qr_token) from public.orders o
   where o.buyer_id = ''00000000-0000-0000-0000-000000000022'' and o.status = ''paid'' limit 1',
  'smoke: vendor confirms pickup via QR'
);
reset role;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000022';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000022","role":"authenticated"}';
select lives_ok(
  'select public.rate_order(
     (select id from public.orders
      where buyer_id = ''00000000-0000-0000-0000-000000000022''
        and status = ''picked_up'' and picked_up_at > now() - interval ''1 minute''
      limit 1), 5, ''{value}'')',
  'smoke: buyer rates the box'
);
reset role;
select is(
  (select (rating_avg > 0)::text from public.restaurants where id = '10000000-0000-0000-0000-000000000001'),
  'true', 'rating_avg recomputed > 0'
);
reset role;

select * from finish();
rollback;
