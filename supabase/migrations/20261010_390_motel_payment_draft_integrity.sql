-- Upgrade 390: read-only validation of an existing payment draft.
-- Does not collect, settle, or reserve funds.
create or replace function public.gs_staff_check_motel_food_payment_draft(p_intent_id uuid)
returns table(intent_id uuid,check_status text,method text,amount_iqd bigint,
 invoice_amount_iqd bigint,invoice_payment_status text,details text)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_payment_intent_drafts%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_check record; v_status text; v_details text;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v from public.gs_motel_food_payment_intent_drafts d
 where d.id=p_intent_id;
 if not found then raise exception 'Payment draft not found'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices f
 where f.id=v.finance_invoice_id;
 if not found then raise exception 'Finance invoice missing'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(v.finance_invoice_id);
 if v.status='cancelled' then
  v_status:='cancelled'; v_details:='Draft cancelled; cannot be used for payment';
 elsif v_invoice.payment_status <> 'unpaid' then
  v_status:='blocked'; v_details:='Finance invoice is not unpaid';
 elsif v_check.check_status is distinct from 'matched' then
  v_status:='blocked'; v_details:='Source reconciliation failed: '||coalesce(v_check.details,'');
 elsif v.amount_iqd is distinct from v_invoice.total_iqd then
  v_status:='blocked'; v_details:='Draft amount differs from current finance invoice';
 else
  v_status:='ready_for_future_integration';
  v_details:='Draft matches unpaid reconciled invoice. Payment processing is not enabled.';
 end if;
 return query select v.id,v_status,v.method,v.amount_iqd,v_invoice.total_iqd,
 v_invoice.payment_status,v_details;
end; $$;
revoke all on function public.gs_staff_check_motel_food_payment_draft(uuid) from public,anon;
grant execute on function public.gs_staff_check_motel_food_payment_draft(uuid) to authenticated;
