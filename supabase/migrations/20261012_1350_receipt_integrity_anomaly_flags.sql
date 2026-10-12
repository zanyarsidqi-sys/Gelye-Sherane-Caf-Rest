-- Read-only upgrade: flag anomalous legacy cash receipt references and amounts.
-- Diagnostic only: NEVER infer a settled balance from cash receipts alone.
create or replace function public.gs_standing_cash_receipt_integrity(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_count bigint; v_total numeric; v_duplicates bigint; v_null_refs bigint;
 v_invalid_amounts bigint; v_order_exists boolean;
begin
 if auth.uid() is null or not public.gs_can_access('payments_management','can_view')
    or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Receipt inspection not authorized';
 end if;
 if p_order_id is null or p_order_id <= 0 then
   raise exception 'Invalid order identifier';
 end if;
 select exists(select 1 from public.gs_orders o where o.id=p_order_id)
 into v_order_exists;
 if not v_order_exists then raise exception 'Order not found' using errcode='P0002'; end if;
 select count(*), coalesce(sum(p.amount_iqd),0),
   count(p.reference) - count(distinct p.reference),
   count(*) filter (where p.reference is null),
   count(*) filter (where p.amount_iqd is null or p.amount_iqd <= 0)
 into v_count,v_total,v_duplicates,v_null_refs,v_invalid_amounts
 from public.gs_cash_payments p where p.order_id=p_order_id;
 return jsonb_build_object('order_id',p_order_id,
   'cash_receipt_count',v_count,'cash_receipt_total_iqd',v_total,
   'duplicate_reference_count',v_duplicates,'null_reference_count',v_null_refs,
   'invalid_amount_count',v_invalid_amounts,
   'receipt_references_unique',v_duplicates=0 and v_null_refs=0,
   'requires_finance_review',v_duplicates>0 or v_null_refs>0 or v_invalid_amounts>0,
   'settlement_confirmed',false,'all_method_reconciled',false,
   'scope','legacy_cash_receipts_only',
   'warning','Cash receipt diagnostics do not prove remaining balance or settlement.');
end $$;
revoke all on function public.gs_standing_cash_receipt_integrity(bigint) from public,anon;
grant execute on function public.gs_standing_cash_receipt_integrity(bigint) to authenticated;
