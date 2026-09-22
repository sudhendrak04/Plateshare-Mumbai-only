-- Stage 3 · 0012_rpc_sweeps — idempotent sweeps (doc/04 §4)
-- Callable by cron (service role) and by postgres in tests.
-- Revoke from clients; grant to service_role only.

-- expired payment holds → release inventory
create or replace function public.sweep_holds()
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_count int := 0;
  v_order public.orders;
begin
  for v_order in
    select * from public.orders
    where status = 'reserved' and expires_at is not null and expires_at < now()
  loop
    update public.orders set status = 'cancelled' where id = v_order.id;

    update public.listings
    set qty_left = least(qty_total, qty_left + v_order.qty)
    where id = v_order.listing_id;

    if (select status from public.listings where id = v_order.listing_id) = 'sold_out'
       and (select qty_left from public.listings where id = v_order.listing_id) > 0 then
      update public.listings set status = 'live' where id = v_order.listing_id;
    end if;

    perform public.audit('orders', v_order.id::text, 'hold_expired',
      '{"status":"reserved"}', '{"status":"cancelled"}');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- window close → expire listings; unpicked orders → no_show + buyer strike (doc/07 §2)
create or replace function public.sweep_listings()
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_count int := 0;
  v_listing public.listings;
  v_order public.orders;
begin
  for v_listing in
    select l.* from public.listings l
    join public.pickup_windows w on w.listing_id = l.id
    where l.status = 'live'
      and w.end_at + (w.grace_min * interval '1 minute') < now()
  loop
    update public.listings set status = 'expired' where id = v_listing.id;

    for v_order in
      select * from public.orders
      where listing_id = v_listing.id and status in ('reserved', 'paid')
    loop
      update public.orders
      set status = 'no_show', strike_applied = true
      where id = v_order.id;

      update public.profiles
      set no_show_count = no_show_count + 1,
          trust_score = greatest(0, trust_score - 20)
      where id = v_order.buyer_id;

      perform public.notify('N6_no_show', 'push',
        jsonb_build_object('order_id', v_order.id),
        'ord:' || v_order.id::text || ':no_show');

      perform public.audit('orders', v_order.id::text, 'no_show',
        jsonb_build_object('status', v_order.status), '{"status":"no_show"}');
      v_count := v_count + 1;
    end loop;

    perform public.audit('listings', v_listing.id::text, 'expired',
      '{"status":"live"}', '{"status":"expired"}');
  end loop;
  return v_count;
end;
$$;

-- donation claim TTL → release + re-broadcast once → wasted (doc/02 §3.2)
create or replace function public.sweep_donation_ttl()
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_count int := 0;
  v_donation public.donations;
begin
  for v_donation in
    select * from public.donations
    where picked_up_at is null
      and (
        (ngo_id is not null and claim_expires_at is not null and claim_expires_at < now())
        or (ngo_id is null and broadcast_count >= 2 and created_at < now() - interval '30 minutes')
      )
  loop
    if v_donation.broadcast_count < 2 then
      -- release the stale claim and re-broadcast
      update public.donations
      set ngo_id = null, claimed_at = null, claim_expires_at = null,
          broadcast_count = broadcast_count + 1
      where id = v_donation.id;

      perform public.notify('N10_donation_broadcast', 'push',
        jsonb_build_object('donation_id', v_donation.id),
        'don:' || v_donation.id::text || ':b' || (v_donation.broadcast_count + 1)::text || ':push');
      perform public.notify('N10_donation_broadcast', 'whatsapp',
        jsonb_build_object('donation_id', v_donation.id),
        'don:' || v_donation.id::text || ':b' || (v_donation.broadcast_count + 1)::text || ':wa');

      perform public.audit('donations', v_donation.id::text, 'rebroadcast',
        jsonb_build_object('broadcast_count', v_donation.broadcast_count),
        jsonb_build_object('broadcast_count', v_donation.broadcast_count + 1));
    else
      -- final broadcast exhausted → mark listing wasted
      update public.listings
      set status = 'wasted', wasted_at = now()
      where id = v_donation.listing_id;

      perform public.audit('listings', v_donation.listing_id::text, 'wasted',
        '{"status":"donated"}', '{"status":"wasted"}');
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- wrapper for the Stage-7 cron Edge Function
create or replace function public.cron_sweep()
returns jsonb
language plpgsql security definer set search_path = public
as $$
begin
  return jsonb_build_object(
    'holds_released', public.sweep_holds(),
    'listings_swept', public.sweep_listings(),
    'donations_swept', public.sweep_donation_ttl(),
    'ran_at', now()
  );
end;
$$;

revoke execute on function public.sweep_holds() from public, anon, authenticated;
revoke execute on function public.sweep_listings() from public, anon, authenticated;
revoke execute on function public.sweep_donation_ttl() from public, anon, authenticated;
revoke execute on function public.cron_sweep() from public, anon, authenticated;
grant execute on function public.sweep_holds() to service_role;
grant execute on function public.sweep_listings() to service_role;
grant execute on function public.sweep_donation_ttl() to service_role;
grant execute on function public.cron_sweep() to service_role;
