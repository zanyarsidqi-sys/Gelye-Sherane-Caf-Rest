-- Upgrade 387: read-only payment eligibility. No payment writer is enabled.
create or replace function public.gs_staff_motel_food_payment_eligibility(p_finance_invoice_id uuid)
returns table(finance_invoice_id uuid, eligibility_status text, amount_due_iqd bigint,
  payment_status text, source_status text, issue_count integer, details text)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_finance_invoices%rowtype; v_check record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v from public.gs_motel_food_finance_invoices f
 where f.id=p_finance_invoice_id;
 if not found then raise exception 'Finance invoice not found'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(p_finance_invoice_id);
 if v_check.finance_invoice_id is null then raise exception 'Reconciliation result unavailable'; end if;
 return query select v.id,
 case when v_check.check_status='matched' and v.payment_status='unpaid'
 then 'eligible_for_future_payment_integration' else 'blocked' end::text,
 v.total_iqd, v.payment_status, v_check.check_status,
 v_check.issue_count,
 case when v_check.check_status <> 'matched' then 'Source reconciliation failed: '||coalesce(v_check.details,'')
 when v.payment_status <> 'unpaid' then 'Invoice is not unpaid'
 else 'Source verified. Payment collection is not implemented; no payment has been posted.' end::text;
end; $$;
revoke all on function public.gs_staff_motel_food_payment_eligibility(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_payment_eligibility(uuid) to authenticated;
