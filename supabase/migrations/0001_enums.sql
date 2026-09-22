-- Stage 2 · 0001_enums (doc/03-data-model.md)
create type public.user_role as enum ('buyer', 'vendor_owner', 'ngo', 'admin');
create type public.diet_pref as enum ('veg', 'nonveg', 'egg', 'jain', 'no_pref');
create type public.food_type as enum ('pure_veg', 'veg_nonveg', 'egg_ok');
create type public.restaurant_status as enum ('pending', 'verified', 'suspended', 'rejected');
create type public.listing_category as enum ('veg', 'nonveg', 'egg', 'jain_friendly');
create type public.listing_status as enum ('draft', 'live', 'sold_out', 'expired', 'donated', 'wasted');
create type public.pay_method as enum ('prepaid_upi', 'cod');
create type public.order_status as enum ('reserved', 'paid', 'picked_up', 'no_show', 'cancelled', 'refunded');
create type public.payment_status as enum ('created', 'authorized', 'captured', 'failed', 'refunded');
create type public.payout_status as enum ('pending', 'processing', 'paid');
create type public.incident_type as enum ('freshness', 'quantity', 'missing', 'hygiene', 'other');
create type public.incident_status as enum ('open', 'resolved_refund', 'resolved_warning', 'dismissed');
create type public.outbox_status as enum ('pending', 'processing', 'sent', 'failed', 'dead');
