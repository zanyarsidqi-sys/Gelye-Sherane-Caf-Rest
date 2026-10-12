-- Upgrade 412: foundational authoritative credit-account schema.
-- No account provisioning, balance mutations, debit or settlement RPCs are exposed.
create table if not exists public.gs_credit_customers (
 id uuid primary key default extensions.gen_random_uuid(),
 customer_reference text not null unique check(length(btrim(customer_reference)) between 3 and 100),
 display_name text not null check(length(btrim(display_name)) between 1 and 120),
 verification_status text not null default 'unverified'
  check(verification_status in ('unverified','review_required','verified','suspended')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id)
);
create table if not exists public.gs_credit_accounts (
 id uuid primary key default extensions.gen_random_uuid(),
 customer_id uuid not null references public.gs_credit_customers(id),
 account_reference text not null unique check(length(btrim(account_reference)) between 3 and 100),
 currency text not null default 'IQD' check(currency='IQD'),
 account_status text not null default 'pending'
  check(account_status in ('pending','active','frozen','closed')),
 credit_limit_iqd bigint not null default 0 check(credit_limit_iqd>=0),
 outstanding_iqd bigint not null default 0 check(outstanding_iqd>=0),
 version bigint not null default 0 check(version>=0),
 created_at timestamptz not null default now(),
 unique(id,customer_id),
 check(outstanding_iqd<=credit_limit_iqd)
);
create table if not exists public.gs_credit_account_journal (
 id uuid primary key default extensions.gen_random_uuid(),
 account_id uuid not null references public.gs_credit_accounts(id),
 external_idempotency_key text not null unique,
 event_kind text not null check(event_kind in ('charge','repayment','reversal','adjustment')),
 delta_outstanding_iqd bigint not null check(delta_outstanding_iqd<>0),
 outstanding_after_iqd bigint not null check(outstanding_after_iqd>=0),
 source_request_id uuid references public.gs_motel_credit_verification_requests(id),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id),
 note text not null default ''
);
create unique index if not exists gs_credit_journal_one_charge_per_request
 on public.gs_credit_account_journal(source_request_id)
 where source_request_id is not null and event_kind='charge';
create table if not exists public.gs_credit_account_registry_links (
 registry_id uuid primary key references public.gs_motel_credit_barcode_registry(id),
 account_id uuid not null references public.gs_credit_accounts(id),
 link_status text not null default 'pending'
  check(link_status in ('pending','verified','revoked')),
 linked_at timestamptz not null default now(),
 linked_by uuid not null references auth.users(id),
 verified_at timestamptz,
 verified_by uuid references auth.users(id),
 check ((link_status='verified' and verified_at is not null and verified_by is not null)
  or (link_status<>'verified' and verified_at is null and verified_by is null))
);
-- Defense in depth: direct client reads and writes are denied, including future tables.
alter table public.gs_credit_customers enable row level security;
alter table public.gs_credit_accounts enable row level security;
alter table public.gs_credit_account_journal enable row level security;
alter table public.gs_credit_account_registry_links enable row level security;
revoke all on public.gs_credit_customers from public,anon,authenticated;
revoke all on public.gs_credit_accounts from public,anon,authenticated;
revoke all on public.gs_credit_account_journal from public,anon,authenticated;
revoke all on public.gs_credit_account_registry_links from public,anon,authenticated;

-- Read-only structural readiness; deliberately never exposes balances.
create or replace function public.gs_staff_credit_account_schema_status()
returns table(component text, status text, detail text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query values
 ('customer_identity'::text,'schema_ready'::text,'Identity records exist; verified identity process not connected'),
 ('account_and_limit','schema_ready','Accounts have nonnegative outstanding and credit-limit constraints; no verified balance authority yet'),
 ('immutable_journal_design','schema_ready','Journal structure and idempotency keys exist; no posting RPC is available'),
 ('barcode_link','schema_ready','Link table exists; ownership verification workflow not connected'),
 ('atomic_debit','blocked','No authorized posting or debit RPC exists'),
 ('credit_settlement','blocked','Credit payment remains disabled');
end $$;
revoke all on function public.gs_staff_credit_account_schema_status() from public,anon;
grant execute on function public.gs_staff_credit_account_schema_status() to authenticated;
