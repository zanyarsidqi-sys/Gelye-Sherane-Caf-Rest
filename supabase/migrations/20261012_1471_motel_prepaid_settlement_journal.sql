-- Motel-only settlement ledger: never cast UUID invoice identities to cafe bigint order IDs.
-- This journal is not the gs_unified_payment_ledger and does not certify Dashboard totals.
create table if not exists public.gs_motel_invoice_prepaid_settlement_journal (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id) on delete restrict,
 allocation_id uuid not null unique references public.gs_motel_prepaid_invoice_allocations(id) on delete restrict,
 receipt_id uuid not null unique references public.gs_motel_prepaid_verified_receipts(id) on delete restrict,
 amount_iqd bigint not null check(amount_iqd>0),
 posted_by uuid not null references auth.users(id),
 posted_at timestamptz not null default now()
);
alter table public.gs_motel_invoice_prepaid_settlement_journal enable row level security;
revoke all on public.gs_motel_invoice_prepaid_settlement_journal from public,anon,authenticated;
create or replace function public.gs_financial_post_motel_prepaid_settlement(p_allocation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.gs_motel_prepaid_invoice_allocations%rowtype;
 i public.gs_motel_food_finance_invoices%rowtype;
 r public.gs_motel_prepaid_verified_receipts%rowtype;
 j public.gs_motel_invoice_prepaid_settlement_journal%rowtype;
 v_check record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Invoice payment permission required' using errcode='42501'; end if;
 if p_allocation_id is null then raise exception 'Allocation ID required' using errcode='22023'; end if;
 select * into a from public.gs_motel_prepaid_invoice_allocations where id=p_allocation_id for update;
 if not found then raise exception 'Allocation not found' using errcode='P0002'; end if;
 select * into i from public.gs_motel_food_finance_invoices where id=a.finance_invoice_id for update;
 if not found then raise exception 'Invoice missing' using errcode='P0002'; end if;
 select * into r from public.gs_motel_prepaid_verified_receipts where id=a.receipt_id for share;
 if not found then raise exception 'Receipt missing' using errcode='P0002'; end if;
 select * into j from public.gs_motel_invoice_prepaid_settlement_journal where finance_invoice_id=i.id for update;
 if found then
  if j.allocation_id<>a.id or j.receipt_id<>r.id or j.amount_iqd<>a.amount_iqd
  then raise exception 'Conflicting settlement journal'; end if;
  return jsonb_build_object('journal_id',j.id,'already_posted',true,'invoice_id',i.id,
   'amount_iqd',j.amount_iqd,'invoice_status_updated',false,'unified_ledger_posted',false,'dashboard_certified',false);
 end if;
 if i.payment_status<>'unpaid' or i.total_iqd<=0 or a.amount_iqd<>i.total_iqd
 or r.confirmed_amount_iqd<>a.amount_iqd or r.finance_invoice_id<>i.id or r.currency<>'IQD'
 then raise exception 'Invoice, receipt or allocation mismatch'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(i.id);
 if v_check.check_status is distinct from 'matched' then raise exception 'Invoice source integrity not matched'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements where finance_invoice_id=i.id)
 or exists(select 1 from public.gs_financial_credit_invoice_charge_links where finance_invoice_id=i.id)
 then raise exception 'Conflicting cash or credit settlement'; end if;
 insert into public.gs_motel_invoice_prepaid_settlement_journal(finance_invoice_id,allocation_id,receipt_id,amount_iqd,posted_by)
 values(i.id,a.id,r.id,a.amount_iqd,auth.uid()) returning * into j;
 return jsonb_build_object('journal_id',j.id,'already_posted',false,'invoice_id',i.id,
  'amount_iqd',j.amount_iqd,'invoice_status_updated',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_post_motel_prepaid_settlement(uuid) from public,anon;
grant execute on function public.gs_financial_post_motel_prepaid_settlement(uuid) to authenticated;
-- Append-only: recorded financial journal rows cannot be altered or removed.
create or replace function public.gs_motel_prepaid_journal_immutable()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Motel prepaid settlement journal is append-only'; end $$;
drop trigger if exists gs_motel_prepaid_journal_immutable on public.gs_motel_invoice_prepaid_settlement_journal;
create trigger gs_motel_prepaid_journal_immutable before update or delete
on public.gs_motel_invoice_prepaid_settlement_journal for each row
execute function public.gs_motel_prepaid_journal_immutable();
