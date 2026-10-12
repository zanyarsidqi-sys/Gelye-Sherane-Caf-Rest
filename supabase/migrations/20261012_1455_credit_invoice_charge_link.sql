-- Upgrade 1455: durable source-backed credit charge -> motel invoice link.
-- This is evidence of a credit ACCOUNT charge only, NOT invoice settlement.
-- No fabricated numeric cafe-order identity or certified IQD totals.
create table if not exists public.gs_financial_credit_invoice_charge_links (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id) on delete restrict,
 credit_request_id uuid not null unique references public.gs_motel_credit_verification_requests(id) on delete restrict,
 credit_journal_id uuid not null unique references public.gs_credit_account_journal(id) on delete restrict,
 account_id uuid not null references public.gs_credit_accounts(id) on delete restrict,
 amount_iqd bigint not null check(amount_iqd > 0),
 record_state text not null default 'charge_recorded_unsettled' check(record_state='charge_recorded_unsettled'),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id)
);
alter table public.gs_financial_credit_invoice_charge_links enable row level security;
revoke all on public.gs_financial_credit_invoice_charge_links from public,anon,authenticated;

-- Trigger executes in the same transaction as journal INSERT: any mismatch aborts the charge.
create or replace function public.gs_financial_link_credit_charge_to_invoice()
returns trigger language plpgsql security definer set search_path='' as $$
declare
 v_request public.gs_motel_credit_verification_requests%rowtype;
 v_draft public.gs_motel_food_payment_intent_drafts%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_link public.gs_financial_credit_invoice_charge_links%rowtype;
begin
 if new.event_kind <> 'charge' then return new; end if;
 if new.source_request_id is null or new.delta_outstanding_iqd<=0 or new.created_by is null then
  raise exception 'Source-backed positive credit charge required' using errcode='22023'; end if;
 select * into v_request from public.gs_motel_credit_verification_requests
  where id=new.source_request_id;
 if not found or v_request.amount_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge/request amount mismatch' using errcode='22023'; end if;
 select * into v_draft from public.gs_motel_food_payment_intent_drafts
  where id=v_request.intent_id;
 if not found or v_draft.method <> 'credit' or v_draft.amount_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge/draft mismatch' using errcode='22023'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices
  where id=v_draft.finance_invoice_id for update;
 if not found or v_invoice.payment_status <> 'unpaid' or v_invoice.total_iqd is distinct from new.delta_outstanding_iqd then
  raise exception 'Credit charge requires matching unpaid invoice' using errcode='22023'; end if;
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
drop trigger if exists gs_financial_link_credit_charge_after_insert on public.gs_credit_account_journal;
create trigger gs_financial_link_credit_charge_after_insert
 after insert on public.gs_credit_account_journal for each row
 execute function public.gs_financial_link_credit_charge_to_invoice();

-- Block tampering with durable source links; corrections require a separately audited reversal model.
create or replace function public.gs_financial_credit_charge_link_immutable()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 raise exception 'Credit invoice charge links are immutable' using errcode='42501';
end $$;
revoke all on function public.gs_financial_credit_charge_link_immutable() from public,anon,authenticated;
drop trigger if exists gs_financial_credit_charge_link_no_mutation on public.gs_financial_credit_invoice_charge_links;
create trigger gs_financial_credit_charge_link_no_mutation
 before update or delete on public.gs_financial_credit_invoice_charge_links for each row
 execute function public.gs_financial_credit_charge_link_immutable();
