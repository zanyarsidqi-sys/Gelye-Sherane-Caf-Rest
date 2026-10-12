-- Upgrade 401: read-only credit settlement prerequisites. No credit account is charged.
create or replace function public.gs_staff_check_motel_credit_readiness(p_intent_id uuid)
returns table(intent_id uuid, invoice_id uuid, amount_iqd bigint, readiness_status text, details text)
language plpgsql security definer set search_path = '' as $$
declare
 v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_p public.gs_motel_food_payment_allocation_plans%rowtype;
 v_s record;
 v_check record;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id;
 if not found then raise exception 'Payment draft missing'; end if;
 if v_d.method <> 'credit' then raise exception 'Credit draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id;
 if not found then raise exception 'Invoice missing'; end if;
 select * into v_p from public.gs_motel_food_payment_allocation_plans where intent_id=v_d.id;
 select * into v_s from public.gs_staff_check_motel_payment_source(v_d.id);
 select * into v_check from public.gs_staff_check_motel_food_payment_draft(v_d.id);
 return query select v_d.id,v_f.id,v_d.amount_iqd,
 case
 when v_d.status <> 'draft' then 'blocked_inactive_draft'
 when v_f.payment_status <> 'unpaid' then 'blocked_invoice_paid'
 when v_d.amount_iqd <> v_f.total_iqd then 'blocked_amount_mismatch'
 when v_check.check_status is distinct from 'ready_for_future_integration' then 'blocked_draft_integrity'
 when v_s.source_status is distinct from 'source_verified_ledger_mapping_pending' then 'blocked_source'
 when v_p.id is null or v_p.method <> 'credit' or v_p.amount_iqd <> v_d.amount_iqd
   or v_p.finance_invoice_id <> v_f.id then 'blocked_allocation_plan'
 else 'requires_credit_account_verification' end::text,
 'Credit barcode/account ownership, available balance, authorization, and debit idempotency must be verified by a future credit backend. No debit is performed.'::text;
end; $$;
revoke all on function public.gs_staff_check_motel_credit_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_check_motel_credit_readiness(uuid) to authenticated;
