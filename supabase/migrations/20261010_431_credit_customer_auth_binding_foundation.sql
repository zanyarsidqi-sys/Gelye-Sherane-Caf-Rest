-- Upgrade 431: customer-authentication binding foundation.
-- Deliberately no staff or customer API can claim an identity or record consent.
-- Only a separately verified identity onboarding workflow may populate bindings.
create table if not exists public.gs_credit_customer_auth_bindings (
 id uuid primary key default gen_random_uuid(),
 customer_id uuid not null references public.gs_credit_customers(id),
 auth_user_id uuid not null references auth.users(id),
 status text not null default 'pending' check(status in ('pending','verified','revoked')),
 verification_method text,
 verification_reference text,
 verified_at timestamptz,
 verified_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 constraint gs_credit_auth_verified_proof check(
  (status='verified' and verified_at is not null and verified_by is not null
   and nullif(btrim(verification_method),'') is not null
   and nullif(btrim(verification_reference),'') is not null)
  or status <> 'verified')
);
create unique index if not exists gs_credit_customer_auth_one_verified_customer
 on public.gs_credit_customer_auth_bindings(customer_id) where status='verified';
create unique index if not exists gs_credit_customer_auth_one_verified_user
 on public.gs_credit_customer_auth_bindings(auth_user_id) where status='verified';
alter table public.gs_credit_customer_auth_bindings enable row level security;
revoke all on public.gs_credit_customer_auth_bindings from public,anon,authenticated;
-- Customer can read only their own binding status; no sensitive identity evidence returned.
create or replace function public.gs_credit_my_identity_binding_status()
returns table(binding_status text, customer_reference text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Customer authentication required'; end if;
 return query select b.status,c.customer_reference
 from public.gs_credit_customer_auth_bindings b
 join public.gs_credit_customers c on c.id=b.customer_id
 where b.auth_user_id=auth.uid() and b.status='verified'
 limit 1;
end $$;
revoke all on function public.gs_credit_my_identity_binding_status() from public,anon;
grant execute on function public.gs_credit_my_identity_binding_status() to authenticated;
-- Explicitly no INSERT/UPDATE/DELETE privileges or approval RPC. A signed-in user
-- alone does not prove ownership of a credit account. Customer consent stays blocked.
