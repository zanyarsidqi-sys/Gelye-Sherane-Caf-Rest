-- DRAFT read model for scheduled motel meals. No barcode secrets exposed.
-- Reservation IDs must be resolved server-side; do not use a barcode as authorization.
create table if not exists public.gs_motel_meal_offers (
 id bigint generated always as identity primary key,
 reservation_reference text not null,
 room_label text not null,
 scheduled_delivery_at timestamptz not null,
 meal_summary text not null,
 payment_mode text not null check(payment_mode in
  ('included_in_reservation','prepaid_with_reservation','pay_on_delivery')),
 payment_status text not null default 'unverified' check(payment_status in
  ('unverified','confirmed','due_on_delivery','refunded')),
 delivery_status text not null default 'scheduled' check(delivery_status in
  ('scheduled','preparing','ready','out_for_delivery','delivered','cancelled')),
 created_at timestamptz not null default now()
);
alter table public.gs_motel_meal_offers enable row level security;
revoke all on public.gs_motel_meal_offers from anon,authenticated;

create or replace function public.gs_dashboard_motel_meal_offers(p_filter text default 'upcoming')
returns table (
 id bigint, reservation_reference text, room_label text,
 scheduled_delivery_at timestamptz, meal_summary text,
 payment_mode text, payment_status text, delivery_status text
) language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view')
   or not public.gs_can_access('motel_orders','can_view') then
   raise exception 'Motel meal offers access denied';
 end if;
 if p_filter not in ('upcoming','all') then raise exception 'Invalid filter'; end if;
 return query select m.id,m.reservation_reference,m.room_label,
   m.scheduled_delivery_at,m.meal_summary,m.payment_mode,
   m.payment_status,m.delivery_status
 from public.gs_motel_meal_offers m
 where p_filter='all' or (
   m.delivery_status not in ('delivered','cancelled')
   and m.scheduled_delivery_at >= now()-interval '1 day')
 order by m.scheduled_delivery_at asc limit 200;
end; $$;
revoke all on function public.gs_dashboard_motel_meal_offers(text) from public,anon;
grant execute on function public.gs_dashboard_motel_meal_offers(text) to authenticated;
-- TODO: link reservation primary key, meal order items, tourism pricing,
-- secure barcode lookup, verified payment ledger, scheduling and kitchen actions.
