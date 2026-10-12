-- Upgrade 1465: authenticated source-backed prepaid receipt review for staged allocation.
-- Receipt verification is performed OUTSIDE this function by the trusted payment provider.
-- Review is advisory; allocation RPC must revalidate under invoice and receipt locks.
create or replace function public.gs_financial_review_verified_prepaid_receipt(p_receipt_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.gs_motel_prepaid_verified_receipts%rowtype;
 i public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_motel_prepaid_invoice_allocations%rowtype;
 v_check record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and invoice payment editing required' using errcode='42501';
 end if;
 if p_receipt_id is null then raise exception 'Receipt ID required' using errcode='22023'; end if;
 select * into r from public.gs_motel_prepaid_verified_receipts where id=p_receipt_id;
 if not found then raise exception 'Verified receipt not found' using errcode='P0002'; end if;
 select * into i from public.gs_motel_food_finance_invoices where id=r.finance_invoice_id;
 if not found or i.payment_status <> 'unpaid' or i.total_iqd<=0
 or i.total_iqd is distinct from r.confirmed_amount_iqd then
  raise exception 'Invoice and provider receipt mismatch' using errcode='22023'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(i.id);
 if v_check.check_status is distinct from 'matched' then
  raise exception 'Invoice source lines not reconciled' using errcode='22023'; end if;
 select * into a from public.gs_motel_prepaid_invoice_allocations where receipt_id=r.id;
 if found and (a.finance_invoice_id is distinct from i.id or a.amount_iqd is distinct from r.confirmed_amount_iqd) then
  raise exception 'Receipt allocation conflicts with source' using errcode='23505'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements where finance_invoice_id=i.id)
 or exists(select 1 from public.gs_financial_credit_invoice_charge_links where finance_invoice_id=i.id) then
  raise exception 'Competing payment method exists' using errcode='23505'; end if;
 return pg_catalog.jsonb_build_object('receipt_id',r.id,'finance_invoice_id',i.id,
  'amount_iqd',r.confirmed_amount_iqd,'provider',r.provider,
  'already_allocated',a.id is not null,'eligible_for_allocation',true,
  'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_review_verified_prepaid_receipt(uuid) from public,anon;
grant execute on function public.gs_financial_review_verified_prepaid_receipt(uuid) to authenticated;
