-- Upgrade 1352: read-only UUID-native motel Pending Payment invoice integrity.
-- Never use this function to authorize collection or compute a chargeable balance.
create or replace function public.gs_pending_payment_motel_invoice_integrity(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_line_count bigint; v_line_total numeric; v_cash_count bigint; v_cash_total numeric;
 v_invalid_lines bigint; v_requires_review boolean;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
  raise exception 'Pending Payment inspection not authorized' using errcode='42501';
 end if;
 if p_invoice_id is null then raise exception 'Invoice ID required' using errcode='22023'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Motel finance invoice not found' using errcode='P0002'; end if;
 select count(*),coalesce(sum(amount_iqd),0),count(*) filter(where amount_iqd <= 0)
 into v_line_count,v_line_total,v_invalid_lines
 from public.gs_motel_food_finance_invoice_lines where finance_invoice_id=p_invoice_id;
 select count(*),coalesce(sum(amount_iqd),0)
 into v_cash_count,v_cash_total
 from public.gs_motel_food_cash_settlements where finance_invoice_id=p_invoice_id;
 v_requires_review := v_line_count <> v_invoice.source_count
 or v_line_total <> v_invoice.total_iqd or v_invalid_lines > 0
 or (v_invoice.payment_status='unpaid' and v_cash_count > 0)
 or (v_invoice.payment_status='paid_cash' and (v_cash_count <> 1 or v_cash_total <> v_invoice.total_iqd))
 or (v_invoice.payment_status not in ('unpaid','paid_cash'));
 return jsonb_build_object('invoice_id',p_invoice_id,'invoice_status',v_invoice.payment_status,
  'invoice_total_iqd',v_invoice.total_iqd,'line_count',v_line_count,
  'line_total_iqd',v_line_total,'invalid_line_count',v_invalid_lines,
  'cash_settlement_count',v_cash_count,'cash_settlement_total_iqd',v_cash_total,
  'requires_finance_review',v_requires_review,'collection_authorized',false,
  'settlement_confirmed',false,'scope','read_only_motel_invoice_integrity',
  'warning','Diagnostic only: other payment channels may exist. Never collect based on this response.');
end $$;
revoke all on function public.gs_pending_payment_motel_invoice_integrity(uuid) from public,anon;
grant execute on function public.gs_pending_payment_motel_invoice_integrity(uuid) to authenticated;
