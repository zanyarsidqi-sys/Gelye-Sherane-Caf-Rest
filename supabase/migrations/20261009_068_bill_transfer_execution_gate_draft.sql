-- Upgrade 68 DRAFT: enforce transfer execution fail-closed until
-- all payment sources and transfer allocation are authoritative.
-- This is a deliberately non-mutating endpoint with a stable client contract.
create or replace function public.gs_apply_table_bill_transfer(
 p_request_id bigint,
 p_idempotency_key uuid
) returns bigint
language plpgsql security definer set search_path='' as $$
declare
 v_request public.gs_table_bill_transfer_requests%rowtype;
 v_selected_count bigint;
 v_cash_count bigint;
 v_external_count bigint;
 v_waiver_count bigint;
 v_ledger_count bigint;
begin
 if auth.uid() is null
    or not public.gs_can_access('table_orders','can_edit')
    or not public.gs_can_access('invoices_payments','can_edit') then
   raise exception 'Bill transfer execution permission denied';
 end if;
 if p_request_id is null or p_idempotency_key is null then
   raise exception 'Request and idempotency key are required';
 end if;
 -- Lock request to make its state explicit; no mutations are performed.
 select * into v_request
 from public.gs_table_bill_transfer_requests
 where id=p_request_id for update;
 if not found then raise exception 'Transfer request not found'; end if;
 if v_request.status<>'pending' then
   raise exception 'Transfer request not pending';
 end if;
 select count(*)::bigint into v_selected_count
 from public.gs_table_bill_transfer_request_items
 where transfer_request_id=p_request_id;
 if v_selected_count=0 then raise exception 'No selected items'; end if;
 select count(*)::bigint into v_cash_count
 from public.gs_cash_payments p
 join public.gs_orders o on o.id=p.order_id
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_table_bill_transfer_request_items r on r.order_item_id=i.id
 where r.transfer_request_id=p_request_id;
 select count(*)::bigint into v_external_count
 from public.gs_external_payment_evidence p
 join public.gs_orders o on o.id=p.order_id
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_table_bill_transfer_request_items r on r.order_item_id=i.id
 where r.transfer_request_id=p_request_id;
 select count(*)::bigint into v_waiver_count
 from public.gs_owner_guest_offers p
 join public.gs_orders o on o.id=p.order_id
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_table_bill_transfer_request_items r on r.order_item_id=i.id
 where r.transfer_request_id=p_request_id
   and p.status in ('pending','verified');
 select count(*)::bigint into v_ledger_count
 from public.gs_unified_payment_ledger p
 join public.gs_orders o on o.id=p.order_id
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_table_bill_transfer_request_items r on r.order_item_id=i.id
 where r.transfer_request_id=p_request_id;
 -- Intentionally never execute transfer, including when all counts are zero:
 -- zero recorded transactions does not prove zero external settlement.
 raise exception using
   errcode='P0001',
   message='Transfer execution disabled: authoritative settlement and item-level payment allocation not implemented',
   hint='Use gs_table_transfer_financial_preflight and resolve legacy cash, provider, credit, and owner-waiver reconciliation first';
end; $$;
revoke all on function public.gs_apply_table_bill_transfer(bigint,uuid)
 from public,anon;
grant execute on function public.gs_apply_table_bill_transfer(bigint,uuid)
 to authenticated;
