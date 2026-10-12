-- Upgrade 1456: independent invoice-link trigger source verification.
-- This is not a prepaid allocation, invoice settlement or dashboard certification.
-- Existing historical links are not modified or silently promoted.
create or replace function public.gs_financial_link_credit_charge_to_invoice()
returns trigger language plpgsql security definer set search_path='' as $$
declare
 v_request public.gs_motel_credit_verification_requests%rowtype;
 v_draft public.gs_motel_food_payment_intent_drafts%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_link public.gs_financial_credit_invoice_charge_links%rowtype;
 v_registry public.gs_motel_credit_barcode_registry%rowtype;
 v_registry_link public.gs_credit_account_registry_links%rowtype;
 v_account public.gs_credit_accounts%rowtype;
 v_customer public.gs_credit_customers%rowtype;
 v_lines_count bigint;
 v_lines_sum bigint;
begin
 if new.event_kind <> 'charge' then return new; end if;
 if new.source_request_id is null or new.delta_outstanding_iqd<=0 or new.created_by is null then
  raise exception 'Source-backed positive credit charge required' using errcode='22023'; end if;
 select * into v_request from public.gs_motel_credit_verification_requests
  where id=new.source_request_id;
 if not found or v_request.status <> 'pending' or v_request.amount_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge/request amount mismatch' using errcode='22023'; end if;
 -- Source identity must be independently verified, even for privileged journal inserts.
 select * into v_registry from public.gs_motel_credit_barcode_registry
  where id=v_request.registry_id;
 if not found or v_registry.account_status <> 'active' then
  raise exception 'Active barcode registry required for credit invoice linkage' using errcode='42501'; end if;
 select * into v_registry_link from public.gs_credit_account_registry_links
  where registry_id=v_request.registry_id for share;
 if not found or v_registry_link.link_status <> 'verified'
    or v_registry_link.verified_by is null or v_registry_link.verified_at is null
    or v_registry_link.account_id is distinct from new.account_id then
  raise exception 'Verified matching registry-account link required' using errcode='42501'; end if;
 select * into v_account from public.gs_credit_accounts where id=new.account_id for share;
 if not found or v_account.account_status <> 'active' or v_account.currency <> 'IQD'
    or v_account.account_reference is distinct from v_registry.account_reference then
  raise exception 'Credit account and barcode identity mismatch' using errcode='42501'; end if;
 select * into v_customer from public.gs_credit_customers where id=v_account.customer_id;
 if not found or v_customer.verification_status <> 'verified' then
  raise exception 'Verified credit customer required' using errcode='42501'; end if;
 select * into v_draft from public.gs_motel_food_payment_intent_drafts
  where id=v_request.intent_id;
 if not found or v_draft.method <> 'credit' or v_draft.amount_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge/draft mismatch' using errcode='22023'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices
  where id=v_draft.finance_invoice_id for update;
 if not found or v_invoice.payment_status <> 'unpaid' or v_invoice.total_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge requires matching unpaid invoice' using errcode='22023'; end if;
 -- Verify the complete source invoice before creating a durable charge link.
 select count(*),coalesce(sum(amount_iqd),0) into v_lines_count,v_lines_sum
 from public.gs_motel_food_finance_invoice_lines where finance_invoice_id=v_invoice.id;
 if v_lines_count <> v_invoice.source_count or v_lines_sum <> v_invoice.total_iqd then
  raise exception 'Motel invoice source lines do not reconcile' using errcode='22023'; end if;
 if exists(select 1 from public.gs_motel_food_payment_intent_drafts
  where finance_invoice_id=v_invoice.id and id<>v_draft.id) then
  raise exception 'Competing invoice payment draft' using errcode='23505'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements
           where finance_invoice_id=v_invoice.id) then
  raise exception 'Cash and credit settlement collision' using errcode='23505'; end if;
 select * into v_link from public.gs_financial_credit_invoice_charge_links
  where finance_invoice_id=v_invoice.id;
 if found then
  raise exception 'Invoice already has a recorded credit charge' using errcode='23505'; end if;
 insert into public.gs_financial_credit_invoice_charge_links
 (finance_invoice_id,credit_request_id,credit_journal_id,account_id,amount_iqd,created_by)
 values(v_invoice.id,new.source_request_id,new.id,new.account_id,new.delta_outstanding_iqd,new.created_by);
 return new;
end $$;

revoke all on function public.gs_financial_link_credit_charge_to_invoice() from public,anon,authenticated;
