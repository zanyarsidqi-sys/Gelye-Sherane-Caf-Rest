-- Upgrade 71: motel meal reservation verification and item review (DRAFT).
-- No barcode is accepted as proof of identity or payment.
create or replace function public.gs_dashboard_motel_meal_offer_detail(p_offer_id bigint)
returns table (
 offer_id bigint, reservation_reference text, room_label text,
 reservation_id uuid, reservation_verified boolean,
 scheduled_delivery_at timestamptz, payment_mode text,
 payment_status text, payment_verified boolean,
 delivery_status text, product_id bigint, quantity integer,
 included_quantity integer, tourism_unit_price_iqd bigint,
 line_total_iqd bigint, payable_quantity integer,
 verification_status text
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null
   or not public.gs_can_access('dashboard','can_view')
   or not public.gs_can_access('motel_orders','can_view') then
   raise exception 'Motel meal detail access denied';
 end if;
 if p_offer_id is null or not exists (
  select 1 from public.gs_motel_meal_offers where id=p_offer_id
 ) then raise exception 'Meal offer not found'; end if;
 return query
 select m.id,m.reservation_reference,m.room_label,
  m.reservation_id,
  (m.reservation_id is not null and m.reservation_verified_at is not null),
  m.scheduled_delivery_at,m.payment_mode,m.payment_status,
  (m.payment_verified_at is not null),m.delivery_status,
  i.product_id,i.quantity,i.included_quantity,i.tourism_unit_price_iqd,
  (i.quantity::bigint*i.tourism_unit_price_iqd)::bigint,
  (i.quantity-i.included_quantity)::integer,
  case
   when m.reservation_id is null or m.reservation_verified_at is null
    then 'reservation_not_verified'
   when i.id is null then 'no_meal_items'
   when m.payment_mode in ('included_in_reservation','prepaid_with_reservation')
     and (m.payment_verified_at is null or m.payment_status<>'confirmed')
    then 'entitlement_or_payment_not_verified'
   when m.payment_mode='pay_on_delivery'
    then 'payment_due_on_delivery_not_settled'
   else 'recorded_checks_present_external_verification_required'
  end::text
 from public.gs_motel_meal_offers m
 left join public.gs_motel_meal_offer_items i on i.offer_id=m.id
 where m.id=p_offer_id order by i.id;
end; $$;
revoke all on function public.gs_dashboard_motel_meal_offer_detail(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_motel_meal_offer_detail(bigint)
 to authenticated;

-- A future barcode scanner must resolve a random opaque token against a
-- trusted motel reservation service; barcode contents are never authorization.
-- No write RPC to set reservation_verified_at/payment_verified_at is added.
-- Item prices must be validated against server-side tourism price snapshots
-- before actual creation/fulfillment. No order/payment/entitlement is posted.
