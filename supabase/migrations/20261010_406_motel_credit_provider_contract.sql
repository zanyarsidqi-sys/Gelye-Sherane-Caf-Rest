-- Upgrade 406: credit provider integration contract (configuration only).
-- No balance, ownership or debit is inferred from this configuration.
create table if not exists public.gs_motel_credit_provider_contracts (
 id uuid primary key default extensions.gen_random_uuid(),
 provider_key text not null unique check(provider_key ~ '^[a-z][a-z0-9_]{2,63}$'),
 account_id_kind text not null default 'external_reference'
  check(account_id_kind in ('external_reference','uuid')),
 integration_status text not null default 'not_connected'
  check(integration_status in ('not_connected','testing','disabled')),
 balance_unit text not null default 'IQD' check(balance_unit='IQD'),
 supports_owner_verification boolean not null default false
  check(supports_owner_verification=false),
 supports_balance_check boolean not null default false
  check(supports_balance_check=false),
 supports_atomic_debit boolean not null default false
  check(supports_atomic_debit=false),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.gs_motel_credit_provider_contracts enable row level security;
revoke all on public.gs_motel_credit_provider_contracts from public,anon,authenticated;

create or replace function public.gs_staff_register_motel_credit_provider_contract(
 p_provider_key text, p_account_id_kind text default 'external_reference')
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_provider_key is null or p_provider_key !~ '^[a-z][a-z0-9_]{2,63}$'
 or p_account_id_kind not in ('external_reference','uuid')
 then raise exception 'Invalid provider contract'; end if;
 insert into public.gs_motel_credit_provider_contracts
  (provider_key,account_id_kind,created_by)
 values(p_provider_key,p_account_id_kind,auth.uid())
 on conflict(provider_key) do nothing returning id into v_id;
 if v_id is null then
  select id into v_id from public.gs_motel_credit_provider_contracts
  where provider_key=p_provider_key;
 end if;
 return v_id;
end $$;
revoke all on function public.gs_staff_register_motel_credit_provider_contract(text,text) from public,anon;
grant execute on function public.gs_staff_register_motel_credit_provider_contract(text,text) to authenticated;

create or replace function public.gs_staff_motel_credit_backend_readiness(p_intent_id uuid)
returns table(check_name text, check_status text, detail text)
language plpgsql security definer set search_path='' as $$
declare d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 n integer;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized finance viewer required'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id;
 if not found or d.method<>'credit' or d.status<>'draft'
 then raise exception 'Active credit draft required'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id;
 return query select 'invoice'::text,
 case when f.id is not null and f.payment_status='unpaid' and f.total_iqd=d.amount_iqd
 then 'pass' else 'blocked' end::text,
 'Unpaid invoice amount must match the credit draft'::text;
 select count(*) into n from public.gs_motel_credit_verification_requests q
 where q.intent_id=d.id and q.status='pending';
 return query select 'verification_request'::text,
 case when n=1 then 'pending' else 'missing' end::text,
 'Pending requests are not approval or consent'::text;
 select count(*) into n from public.gs_motel_credit_provider_contracts;
 return query select 'credit_provider_contract'::text,
 case when n>0 then 'configured_only' else 'missing' end::text,
 'Provider metadata is not an active integration; no verified balance authority'::text;
 return query select 'owner_verification'::text,'unverified'::text,
 'No customer identity/consent provider integration exists'::text;
 return query select 'authoritative_balance'::text,'unverified'::text,
 'No real-time balance and credit-limit provider integration exists'::text;
 return query select 'atomic_debit'::text,'unverified'::text,
 'No idempotent provider debit and rollback/reconciliation integration exists'::text;
 return query select 'payment_eligible'::text,'blocked'::text,
 'Never settle credit based on provider metadata or pending requests'::text;
end $$;
revoke all on function public.gs_staff_motel_credit_backend_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_motel_credit_backend_readiness(uuid) to authenticated;
