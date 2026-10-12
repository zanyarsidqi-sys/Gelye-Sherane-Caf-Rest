-- Upgrade 450: fail-closed protection of verified customer bindings.
-- No trusted external provider verification workflow exists yet, so activation is prohibited.
create or replace function public.gs_credit_guard_verified_auth_binding()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status = 'verified' then
   -- An employee evidence review is not authoritative identity proof.
   raise exception 'Verified credit identity activation is disabled until authoritative verification is integrated';
 end if;
 if exists (
   select 1 from public.gs_credit_identity_onboarding_requests r
   join public.gs_credit_identity_customer_safety_holds h
     on h.onboarding_request_id=r.id
   where r.customer_id=new.customer_id and r.auth_user_id=new.auth_user_id
 ) and new.status <> 'revoked' then
   raise exception 'Customer safety hold prohibits active or pending identity binding';
 end if;
 return new;
end $$;
drop trigger if exists gs_credit_auth_binding_activation_guard on public.gs_credit_customer_auth_bindings;
create trigger gs_credit_auth_binding_activation_guard
before insert or update on public.gs_credit_customer_auth_bindings
for each row execute function public.gs_credit_guard_verified_auth_binding();

-- Staff diagnostics disclose only activation readiness, never identity documents.
create or replace function public.gs_staff_credit_identity_activation_status(p_request_id uuid)
returns table(check_name text,check_status text,details text)
language plpgsql security definer set search_path='' as $$
declare v_request public.gs_credit_identity_onboarding_requests%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select * into v_request from public.gs_credit_identity_onboarding_requests
 where id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 return query select 'onboarding'::text,
   case when v_request.status='pending' then 'pending' else 'blocked' end::text,
   'Pending onboarding is not verified identity'::text;
 return query select 'customer_safety_hold'::text,
   case when exists(select 1 from public.gs_credit_identity_customer_safety_holds h
     where h.onboarding_request_id=p_request_id) then 'blocked' else 'none' end::text,
   'A customer hold prevents identity activation'::text;
 return query select 'authoritative_verification'::text,'unavailable'::text,
   'No trusted external identity verification provider is integrated'::text;
 return query select 'identity_activation'::text,'blocked'::text,
   'Verified binding creation is prohibited by database trigger'::text;
 return query select 'credit_payment'::text,'blocked'::text,
   'No consent approval or credit debit is enabled'::text;
end $$;
revoke all on function public.gs_staff_credit_identity_activation_status(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_activation_status(uuid) to authenticated;
