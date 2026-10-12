-- Upgrade 76: item-level transfer eligibility inspection (DRAFT).
-- Read-only. Never treats an absence of payment records as proof of unpaid balance.
create or replace function public.gs_table_transfer_item_preflight(p_request_id bigint)
returns table(
 order_item_id bigint, source_order_id bigint, requested_quantity integer,
 current_quantity integer, unit_price_iqd bigint, requested_value_iqd bigint,
 cash_receipt_count bigint, ledger_entry_count bigint,
 external_evidence_count bigint, owner_offer_count bigint,
 item_ready_for_transfer boolean, blocker text
)
language plpgsql stable security definer set search_path='' as $$
declare v_req public.gs_table_bill_transfer_requests%rowtype;
begin
 if auth.uid() is null
  or not public.gs_can_access('table_orders','can_view')
  or not public.gs_can_access('invoices_payments','can_view')
 then raise exception 'Transfer inspection permission denied'; end if;
 select * into v_req from public.gs_table_bill_transfer_requests
 where id=p_request_id;
 if not found then raise exception 'Transfer request not found'; end if;
 return query
 select i.id,i.order_id,r.requested_quantity,i.quantity,i.unit_price_iqd,
  (r.requested_quantity::bigint*i.unit_price_iqd)::bigint,
  (select count(*) from public.gs_cash_payments c where c.order_id=i.order_id)::bigint,
  (select count(*) from public.gs_unified_payment_ledger l where l.order_id=i.order_id)::bigint,
  (select count(*) from public.gs_external_payment_evidence e where e.order_id=i.order_id)::bigint,
  (select count(*) from public.gs_owner_guest_offers g where g.order_id=i.order_id
   and g.status in ('pending','verified'))::bigint,
  false,
  case
   when v_req.status<>'pending' then 'request_not_pending'
   when o.table_visit_id is distinct from v_req.source_visit_id then 'source_visit_mismatch'
   when r.requested_quantity>i.quantity then 'requested_quantity_exceeds_current'
   when r.requested_quantity<=0 then 'invalid_requested_quantity'
   when i.unit_price_iqd<0 then 'invalid_price'
   when exists(select 1 from public.gs_cash_payments c where c.order_id=i.order_id)
    then 'cash_allocation_not_certified'
   when exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=i.order_id)
    then 'ledger_allocation_not_certified'
   when exists(select 1 from public.gs_external_payment_evidence e where e.order_id=i.order_id)
    then 'external_payment_not_certified'
   when exists(select 1 from public.gs_owner_guest_offers g where g.order_id=i.order_id
    and g.status in ('pending','verified')) then 'owner_offer_allocation_not_certified'
   else 'authoritative_item_settlement_and_atomic_transfer_not_implemented'
  end::text
 from public.gs_table_bill_transfer_request_items r
 join public.gs_order_items i on i.id=r.order_item_id
 join public.gs_orders o on o.id=i.order_id
 where r.transfer_request_id=p_request_id
 order by i.id;
end; $$;
revoke all on function public.gs_table_transfer_item_preflight(bigint) from public,anon;
grant execute on function public.gs_table_transfer_item_preflight(bigint) to authenticated;
-- NEVER expose an execution-ready flag until item-level settlement is
-- authoritative and an atomic idempotent transfer implementation exists.
