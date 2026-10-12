-- Upgrade 454: evaluate historical holds for an existing onboarding request.
-- Read-only: no identity activation or credit debit.
create or replace function public.gs_staff_credit_onboarding_request_hold_status(p_request_id uuid)
returns table(blocked boolean,hold_count bigint,explanation text)
language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_user uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select r.customer_id,r.auth_user_id into v_customer,v_user
 from public.gs_credit_identity_onboarding_requests r where r.id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 return query select count(*)>0,count(*),
 case when count(*)>0 then 'Historical customer safety hold exists. All identity approval remains blocked.'
 else 'No historical safety hold found. Independent identity verification remains required.' end::text
 from public.gs_credit_identity_customer_safety_holds h
 join public.gs_credit_identity_onboarding_requests r on r.id=h.onboarding_request_id
 where r.customer_id=v_customer or r.auth_user_id=v_user;
end $$;
revoke all on function public.gs_staff_credit_onboarding_request_hold_status(uuid) from public,anon;
grant execute on function public.gs_staff_credit_onboarding_request_hold_status(uuid) to authenticated;
