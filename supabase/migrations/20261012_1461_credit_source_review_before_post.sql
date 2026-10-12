-- Upgrade 1461: mandatory, source-backed review of an existing motel credit request.
-- Read-only; the posting RPC must revalidate under locks. No payment certification.
create or replace function public.gs_financial_review_credit_charge_source(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
 q public.gs_motel_credit_verification_requests%rowtype;
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 r public.gs_motel_credit_barcode_registry%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
 c public.gs_credit_customers%rowtype;
 v_count bigint; v_total numeric;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
  or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
  or not coalesce(public.gs_can_access('credit_management','can_edit'),false) then
  raise exception 'Credit finance editor permissions required' using errcode='42501';
 end if;
 if p_request_id is null then raise exception 'Credit request ID required' using errcode='22023'; end if;
 select * into q from public.gs_motel_credit_verification_requests where id=p_request_id;
 if not found or q.status<>'pending' or q.amount_iqd<=0 then
  raise exception 'Pending positive credit request required' using errcode='22023'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=q.intent_id;
 if not found or d.method<>'credit' or d.status<>'draft' or d.amount_iqd<>q.amount_iqd then
  raise exception 'Credit payment draft mismatch' using errcode='22023'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id;
 if not found or f.payment_status<>'unpaid' or f.total_iqd<>q.amount_iqd or f.source_count<=0 then
  raise exception 'Unpaid invoice and credit amount mismatch' using errcode='22023'; end if;
 select count(*),coalesce(sum(amount_iqd),0) into v_count,v_total
  from public.gs_motel_food_finance_invoice_lines where finance_invoice_id=f.id;
 if v_count<>f.source_count or v_total<>f.total_iqd then
  raise exception 'Invoice lines do not reconcile' using errcode='22023'; end if;
 select * into r from public.gs_motel_credit_barcode_registry where id=q.registry_id;
 select * into l from public.gs_credit_account_registry_links where registry_id=q.registry_id;
 if r.id is null or r.account_status<>'active' or l.registry_id is null or
    l.link_status<>'verified' or l.verified_at is null or l.verified_by is null then
  raise exception 'Verified active credit barcode link required' using errcode='42501'; end if;
 select * into a from public.gs_credit_accounts where id=l.account_id;
 select * into c from public.gs_credit_customers where id=a.customer_id;
 if a.id is null or a.account_status<>'active' or a.currency<>'IQD' or
    a.account_reference is distinct from r.account_reference or
    c.id is null or c.verification_status<>'verified' then
  raise exception 'Verified active IQD credit account required' using errcode='42501'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements where finance_invoice_id=f.id)
 or exists(select 1 from public.gs_financial_credit_invoice_charge_links where finance_invoice_id=f.id)
 or exists(select 1 from public.gs_motel_food_payment_intent_drafts where finance_invoice_id=f.id and id<>d.id)
 then raise exception 'Invoice has conflicting payment records' using errcode='23505'; end if;
 return pg_catalog.jsonb_build_object('request_id',q.id,'finance_invoice_id',f.id,
  'amount_iqd',q.amount_iqd,'eligible_for_charge',true,
  'invoice_settled',false,'prepaid_allocated',false,'dashboard_certified',false,
  'warning','Review is advisory; posting RPC revalidates under transactional locks.');
end $$;
revoke all on function public.gs_financial_review_credit_charge_source(uuid) from public,anon;
grant execute on function public.gs_financial_review_credit_charge_source(uuid) to authenticated;
