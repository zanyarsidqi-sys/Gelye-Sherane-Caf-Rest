-- Upgrade 1463: provider-attested prepaid source and atomic invoice allocation.
-- No client may create a confirmed receipt. Trusted server integration must insert
-- provider-verified receipts using privileged credentials after external verification.
-- This does NOT mark motel invoices paid or certify unified ledger/dashboard totals.
create table if not exists public.gs_motel_prepaid_verified_receipts (
 id uuid primary key default extensions.gen_random_uuid(),
 provider text not null check (length(btrim(provider)) between 2 and 80),
 provider_transaction_id text not null check (length(btrim(provider_transaction_id)) between 8 and 200),
 finance_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id),
 confirmed_amount_iqd bigint not null check (confirmed_amount_iqd > 0),
 currency text not null default 'IQD' check (currency='IQD'),
 verified_at timestamptz not null,
 verified_by_service text not null check (length(btrim(verified_by_service)) between 5 and 120),
 provider_proof_sha256 text not null check (provider_proof_sha256 ~ '^[0-9a-f]{64}$'),
 created_at timestamptz not null default now(),
 unique(provider,provider_transaction_id)
);
create unique index if not exists gs_motel_prepaid_receipt_invoice_once
 on public.gs_motel_prepaid_verified_receipts(finance_invoice_id);
create table if not exists public.gs_motel_prepaid_invoice_allocations (
 id uuid primary key default extensions.gen_random_uuid(),
 receipt_id uuid not null unique references public.gs_motel_prepaid_verified_receipts(id),
 finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id),
 amount_iqd bigint not null check (amount_iqd>0),
 allocated_by uuid not null references auth.users(id),
 allocated_at timestamptz not null default now()
);
alter table public.gs_motel_prepaid_verified_receipts enable row level security;
alter table public.gs_motel_prepaid_invoice_allocations enable row level security;
revoke all on public.gs_motel_prepaid_verified_receipts from public,anon,authenticated;
revoke all on public.gs_motel_prepaid_invoice_allocations from public,anon,authenticated;

create or replace function public.gs_financial_allocate_verified_motel_prepaid(p_receipt_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.gs_motel_prepaid_verified_receipts%rowtype;
 i public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_motel_prepaid_invoice_allocations%rowtype;
 v_check record; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and invoice payment editing required' using errcode='42501';
 end if;
 if p_receipt_id is null then raise exception 'Receipt required' using errcode='22023'; end if;
 select * into r from public.gs_motel_prepaid_verified_receipts where id=p_receipt_id for update;
 if not found then raise exception 'Verified receipt not found' using errcode='P0002'; end if;
 select * into i from public.gs_motel_food_finance_invoices where id=r.finance_invoice_id for update;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select * into a from public.gs_motel_prepaid_invoice_allocations where receipt_id=r.id for update;
 if found then
  if a.finance_invoice_id<>i.id or a.amount_iqd<>r.confirmed_amount_iqd then
   raise exception 'Existing allocation mismatch'; end if;
  return jsonb_build_object('allocation_id',a.id,'already_allocated',true,'invoice_id',i.id,
   'amount_iqd',a.amount_iqd,'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
 end if;
 if i.payment_status<>'unpaid' or i.total_iqd<=0 or r.confirmed_amount_iqd<>i.total_iqd then
  raise exception 'Invoice status or amount does not match independently confirmed receipt'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(i.id);
 if v_check.check_status is distinct from 'matched' then
  raise exception 'Invoice source integrity not matched'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements where finance_invoice_id=i.id)
 or exists(select 1 from public.gs_financial_credit_invoice_charge_links where finance_invoice_id=i.id)
 or exists(select 1 from public.gs_motel_prepaid_invoice_allocations where finance_invoice_id=i.id)
 then raise exception 'Invoice already allocated or charged'; end if;
 -- Payment drafts are not payment evidence; conflicting intents require review.
 if exists(select 1 from public.gs_motel_food_payment_intent_drafts
           where finance_invoice_id=i.id and method<>'electronic') then
  raise exception 'Conflicting payment intent requires review'; end if;
 insert into public.gs_motel_prepaid_invoice_allocations(receipt_id,finance_invoice_id,amount_iqd,allocated_by)
 values(r.id,i.id,r.confirmed_amount_iqd,auth.uid()) returning id into v_id;
 return jsonb_build_object('allocation_id',v_id,'already_allocated',false,'invoice_id',i.id,
  'amount_iqd',r.confirmed_amount_iqd,'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_allocate_verified_motel_prepaid(uuid) from public,anon;
grant execute on function public.gs_financial_allocate_verified_motel_prepaid(uuid) to authenticated;

-- Deny mutation of attested source receipts even to accidental application writers;
-- provider corrections require a reviewed migration, never silent overwrite.
create or replace function public.gs_financial_prepaid_immutable() returns trigger
language plpgsql set search_path='' as $$ begin
 raise exception 'Prepaid financial evidence is immutable';
end $$;
drop trigger if exists gs_motel_prepaid_receipt_immutable on public.gs_motel_prepaid_verified_receipts;
create trigger gs_motel_prepaid_receipt_immutable before update or delete
 on public.gs_motel_prepaid_verified_receipts for each row execute function public.gs_financial_prepaid_immutable();
drop trigger if exists gs_motel_prepaid_allocation_immutable on public.gs_motel_prepaid_invoice_allocations;
create trigger gs_motel_prepaid_allocation_immutable before update or delete
 on public.gs_motel_prepaid_invoice_allocations for each row execute function public.gs_financial_prepaid_immutable();
