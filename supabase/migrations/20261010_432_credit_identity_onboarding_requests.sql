-- Upgrade 432: employee-initiated identity onboarding, pending only.
-- Authentication identifiers alone never prove credit-account ownership.
create table if not exists public.gs_credit_identity_onboarding_requests (
 id uuid primary key default gen_random_uuid(),
 customer_id uuid not null references public.gs_credit_customers(id),
 auth_user_id uuid not null references auth.users(id),
 status text not null default 'pending' check(status in ('pending','cancelled')),
 reason text not null check(length(btrim(reason)) between 10 and 1000),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 cancelled_by uuid references auth.users(id),
 cancelled_at timestamptz,
 cancellation_reason text,
 constraint gs_onboarding_cancel_consistency check (
  (status='pending' and cancelled_by is null and cancelled_at is null and cancellation_reason is null)
  or (status='cancelled' and cancelled_by is not null and cancelled_at is not null
   and length(btrim(cancellation_reason)) between 10 and 1000))
);
create unique index if not exists gs_credit_onboarding_one_pending_customer
 on public.gs_credit_identity_onboarding_requests(customer_id) where status='pending';
create unique index if not exists gs_credit_onboarding_one_pending_user
 on public.gs_credit_identity_onboarding_requests(auth_user_id) where status='pending';
alter table public.gs_credit_identity_onboarding_requests enable row level security;
revoke all on public.gs_credit_identity_onboarding_requests from public,anon,authenticated;
create or replace function public.gs_staff_request_credit_identity_onboarding(
 p_customer_id uuid,p_auth_user_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_customer_id is null or p_auth_user_id is null or p_reason is null
 or length(btrim(p_reason)) not between 10 and 1000
 then raise exception 'Valid customer, auth user, and reason required'; end if;
 if not exists(select 1 from public.gs_credit_customers where id=p_customer_id)
 or not exists(select 1 from auth.users where id=p_auth_user_id)
 then raise exception 'Customer or authenticated user does not exist'; end if;
 if exists(select 1 from public.gs_credit_customer_auth_bindings
   where status='verified' and (customer_id=p_customer_id or auth_user_id=p_auth_user_id))
 then raise exception 'An existing verified identity binding requires separate review'; end if;
 insert into public.gs_credit_identity_onboarding_requests
 (customer_id,auth_user_id,reason,requested_by)
 values(p_customer_id,p_auth_user_id,btrim(p_reason),auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_request_credit_identity_onboarding(uuid,uuid,text) from public,anon;
grant execute on function public.gs_staff_request_credit_identity_onboarding(uuid,uuid,text) to authenticated;
create or replace function public.gs_credit_my_pending_identity_onboarding()
returns table(request_id uuid,customer_reference text,requested_at timestamptz,status text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return query select r.id,c.customer_reference,r.requested_at,r.status
 from public.gs_credit_identity_onboarding_requests r
 join public.gs_credit_customers c on c.id=r.customer_id
 where r.auth_user_id=auth.uid() and r.status='pending'
 order by r.requested_at desc limit 10;
end $$;
revoke all on function public.gs_credit_my_pending_identity_onboarding() from public,anon;
grant execute on function public.gs_credit_my_pending_identity_onboarding() to authenticated;
-- There is intentionally no function to mark requests verified or record consent.
