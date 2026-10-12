-- Upgrade 373: read-only reservation reconciliation before official invoice posting.
-- No invoice or payment mutations. Missing/stale/extra reservations block handoff.
create or replace function public.gs_staff_motel_invoice_reservation_reconciliation(p_guest_session_id uuid)
returns table(source_order_id uuid, issue text, expected_amount_iqd bigint, reserved_amount_iqd bigint)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and invoice viewing permissions required';
 end if;
 if not exists (select 1 from public.gs_motel_guest_stay_sessions s where s.id=p_guest_session_id) then
  raise exception 'Guest stay not found';
 end if;
 -- Manifest checks current employee review fingerprint and ledger integrity.
 return query
 with expected as (
  select c.source_order_id as oid,c.source_ledger_id as lid,c.room_id as rid,
         c.amount_iqd as amt,c.review_id as rev,c.review_fingerprint as fp
  from public.gs_staff_motel_food_invoice_crosswalk_preview(p_guest_session_id) c
 ), actual as (
  select r.source_order_id as oid,r.source_ledger_id as lid,r.room_id as rid,
         r.amount_iqd as amt,r.review_id as rev,r.review_fingerprint as fp
  from public.gs_motel_food_invoice_source_reservations r
  where r.guest_session_id=p_guest_session_id
 )
 select coalesce(e.oid,a.oid),
   case when e.oid is null then 'unexpected_reservation'
        when a.oid is null then 'missing_reservation'
        when e.lid is distinct from a.lid or e.rid is distinct from a.rid
          or e.amt is distinct from a.amt or e.rev is distinct from a.rev
          or e.fp is distinct from a.fp then 'reservation_mismatch'
        else 'matched' end,
   e.amt,a.amt
 from expected e full outer join actual a on a.oid=e.oid
 order by coalesce(e.oid,a.oid);
end; $$;
revoke all on function public.gs_staff_motel_invoice_reservation_reconciliation(uuid) from public,anon;
grant execute on function public.gs_staff_motel_invoice_reservation_reconciliation(uuid) to authenticated;
