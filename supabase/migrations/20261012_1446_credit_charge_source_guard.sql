-- Upgrade: enforce source identity on future credit journal charges. No posting API or certified balances.
-- Install after existing journal guard. Existing rows are audited separately, never silently rewritten.
create or replace function public.gs_financial_credit_charge_source_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
declare q public.gs_motel_credit_verification_requests%rowtype;
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_credit_accounts%rowtype;
 c public.gs_credit_customers%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
begin
 if new.event_kind <> 'charge' then return new; end if;
 if new.source_request_id is null or new.delta_outstanding_iqd <= 0 then
  raise exception 'Charge requires positive movement and verification request' using errcode='22023'; end if;
 select * into q from public.gs_motel_credit_verification_requests where id=new.source_request_id;
 if not found or q.status <> 'pending' or q.amount_iqd <> new.delta_outstanding_iqd then
  raise exception 'Credit charge source request is missing, cancelled or amount-mismatched' using errcode='22023'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=q.intent_id;
 if not found or d.method <> 'credit' or d.status <> 'draft' or d.amount_iqd <> q.amount_iqd then
  raise exception 'Credit charge payment intent is not an exact active draft' using errcode='22023'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id;
 if not found or f.payment_status <> 'unpaid' or f.total_iqd <> q.amount_iqd then
  raise exception 'Credit charge invoice is not an exact unpaid source' using errcode='22023'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=q.registry_id;
 if not found or l.link_status <> 'verified' or l.account_id <> new.account_id then
  raise exception 'Credit charge registry-to-account identity is not verified' using errcode='42501'; end if;
 select * into a from public.gs_credit_accounts where id=new.account_id;
 if not found or a.account_status <> 'active' or a.currency <> 'IQD' then
  raise exception 'Credit account is not active and IQD-denominated' using errcode='42501'; end if;
 select * into c from public.gs_credit_customers where id=a.customer_id;
 if not found or c.verification_status <> 'verified' then
  raise exception 'Credit account customer identity not verified' using errcode='42501'; end if;
 if new.outstanding_after_iqd <> a.outstanding_iqd or
    a.outstanding_iqd < new.delta_outstanding_iqd or
    a.outstanding_iqd > a.credit_limit_iqd then
  raise exception 'Journal charge does not match an already committed bounded account balance' using errcode='22023'; end if;
 if exists(select 1 from public.gs_credit_account_journal j
           where j.source_request_id=q.id and j.event_kind='charge') then
  raise exception 'Credit request already charged' using errcode='23505'; end if;
 return new;
end $$;
revoke all on function public.gs_financial_credit_charge_source_guard() from public,anon,authenticated;
drop trigger if exists gs_financial_credit_charge_source_guard_trg on public.gs_credit_account_journal;
create trigger gs_financial_credit_charge_source_guard_trg
 before insert on public.gs_credit_account_journal
 for each row execute function public.gs_financial_credit_charge_source_guard();
