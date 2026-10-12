-- Upgrade 56 DRAFT: motel meal scheduling and join-table transfer foundations.
-- This migration does not generate/accept a barcode as proof of reservation.
-- Reservation authority and payment must be confirmed by the motel backend.
alter table public.gs_motel_meal_offers
  add column if not exists reservation_id uuid,
  add column if not exists reservation_verified_at timestamptz,
  add column if not exists requested_by uuid references auth.users(id),
  add column if not exists delivered_at timestamptz,
  add column if not exists payment_verified_at timestamptz,
  add column if not exists payment_reference text;

create table if not exists public.gs_motel_meal_offer_items (
  id bigint generated always as identity primary key,
  offer_id bigint not null references public.gs_motel_meal_offers(id) on delete restrict,
  product_id bigint not null,
  quantity integer not null check(quantity between 1 and 100),
  tourism_unit_price_iqd bigint not null check(tourism_unit_price_iqd >= 0),
  included_quantity integer not null default 0 check(included_quantity >= 0),
  constraint included_not_above_ordered check(included_quantity <= quantity)
);
create index if not exists gs_motel_meal_offer_items_offer_idx
  on public.gs_motel_meal_offer_items(offer_id);
alter table public.gs_motel_meal_offer_items enable row level security;
revoke all on public.gs_motel_meal_offer_items from anon,authenticated;

-- A verified reservation must be resolved against the motel reservation
-- system by an authenticated reception service; never trust raw barcode text.
-- Prepaid/included meals must be verified against the reservation entitlement
-- and payment ledger before any customer balance is waived.

-- Table join / bill transfer requests: recording intent does not move money.
create table if not exists public.gs_table_bill_transfer_requests (
 id bigint generated always as identity primary key,
 source_visit_id bigint not null references public.gs_table_visits(id),
 destination_visit_id bigint not null references public.gs_table_visits(id),
 requested_by uuid not null references auth.users(id),
 status text not null default 'pending'
   check(status in ('pending','approved','rejected','cancelled','applied')),
 reason text not null check(char_length(reason) between 5 and 500),
 created_at timestamptz not null default now(),
 applied_at timestamptz,
 constraint distinct_table_visits check(source_visit_id <> destination_visit_id)
);
create table if not exists public.gs_table_bill_transfer_request_items (
 id bigint generated always as identity primary key,
 transfer_request_id bigint not null references public.gs_table_bill_transfer_requests(id),
 order_item_id bigint not null references public.gs_order_items(id),
 requested_quantity integer not null check(requested_quantity > 0),
 unique(transfer_request_id,order_item_id)
);
alter table public.gs_table_bill_transfer_requests enable row level security;
alter table public.gs_table_bill_transfer_request_items enable row level security;
revoke all on public.gs_table_bill_transfer_requests from anon,authenticated;
revoke all on public.gs_table_bill_transfer_request_items from anon,authenticated;
-- No direct write grants or transfer execution RPC. Must implement atomic
-- settlement/partial item allocation with locks, audit and idempotency.
