-- Stage 4 · 0013_security_hardening — column-level grants so vendors/buyers
-- cannot self-escalate (status/role/trust are admin- or RPC-only fields).

-- 1. profiles: authenticated may edit only name/diet_pref (+ updated_at via trigger).
--    role, trust_score, no_show_count are RPC/admin-managed.
revoke update on public.profiles from authenticated;
grant update (name, diet_pref, updated_at) on public.profiles to authenticated;

-- belt-and-braces: nobody may change their own role/trust/strikes via client writes
create or replace function public.profiles_no_self_escalation()
returns trigger
language plpgsql
as $$
begin
  -- guard applies only to client (authenticated) writes; RPC/service-role paths exempt
  if current_user <> 'authenticated' then
    return new;
  end if;
  if auth.uid() = new.id and (
    new.role is distinct from old.role
    or new.trust_score is distinct from old.trust_score
    or new.no_show_count is distinct from old.no_show_count
    or new.is_active is distinct from old.is_active
  ) then
    raise exception 'PROFILE_ESCALATION_BLOCKED'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function public.profiles_no_self_escalation();

-- 2. restaurants: vendors may edit profile fields but never their own
--    status / FSSAI / rating (verification is admin-only via RPC)
revoke update on public.restaurants from authenticated;
grant update (name, cuisine_tags, address, geo, open_time, close_time,
              food_type, payout_upi, bank_details, updated_at)
  on public.restaurants to authenticated;

-- 3. listing audit RPCs for the console (admin-only)
create or replace function public.admin_listing_audit()
returns table (
  listing_id uuid, restaurant_name text, status public.listing_status,
  photo_taken_at timestamptz, created_at timestamptz,
  photo_age_flag boolean, reuse_flag boolean, geotag_mismatch_m double precision
)
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;
  return query
  select l.id, r.name, l.status, l.photo_taken_at, l.created_at,
    (l.photo_taken_at is not null and l.photo_taken_at < l.created_at - interval '15 minutes'),
    exists (
      select 1 from public.listings l2
      where l2.photo_url = l.photo_url and l2.id <> l.id and l2.photo_url is not null
    ),
    case
      when l.photo_geo is null or r.geo is null then null
      else extensions.st_distance(l.photo_geo, r.geo)
    end
  from public.listings l
  join public.restaurants r on r.id = l.restaurant_id
  order by l.created_at desc
  limit 200;
end;
$$;

create or replace function public.admin_delist_listing(p_listing_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_status public.listing_status;
begin
  if not public.is_admin() then
    raise exception 'UNAUTHORIZED_ROLE' using errcode = '42501';
  end if;

  select status into v_status from public.listings where id = p_listing_id;
  if not found then
    raise exception 'LISTING_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.listings set status = 'expired' where id = p_listing_id;
  perform public.audit('listings', p_listing_id::text, 'delisted',
    jsonb_build_object('status', v_status), jsonb_build_object('status', 'expired', 'reason', p_reason));
end;
$$;

grant execute on function public.admin_listing_audit() to authenticated;
grant execute on function public.admin_delist_listing(uuid, text) to authenticated;

-- 4. no-arg variant for the NGO portal: uses the caller's own verified NGO geo
create or replace function public.ngo_open_donations()
returns table (donation_id uuid, listing_id uuid, restaurant_name text, qty_left int, broadcast_at timestamptz)
language sql security definer set search_path = public
as $$
  select d.id, d.listing_id, r.name, l.qty_left, d.created_at
  from public.donations d
  join public.listings l on l.id = d.listing_id
  join public.restaurants r on r.id = l.restaurant_id
  join public.ngos n on n.contact_user_id = auth.uid() and n.verified
  where d.ngo_id is null
    and l.status = 'donated'
    and extensions.st_dwithin(r.geo, n.geo, 5000)
  order by d.created_at
$$;

grant execute on function public.ngo_open_donations() to authenticated;
