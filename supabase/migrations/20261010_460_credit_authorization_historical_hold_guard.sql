-- Upgrade 460: reject new credit authorization requests for a credit customer
-- with any historical identity safety hold. A hold cannot be bypassed by
-- creating a new onboarding request or selecting a different credit review.
-- This is a restrictive control, NOT customer consent or payment approval.
create or replace function public.gs_credit_authorization_block_historical_identity_hold()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_customer_id uuid;
begin
 select a.customer_id into v_customer_id
 from public.gs_credit_accounts a where a.id=new.account_id;
 if v_customer_id is null then
   raise exception 'Credit authorization account customer not found';
 end if;
 if exists (
   select 1 from public.gs_credit_identity_customer_safety_holds h
   join public.gs_credit_identity_onboarding_requests r
     on r.id=h.onboarding_request_id
   where r.customer_id=v_customer_id
 ) then
   raise exception 'Credit authorization blocked: customer has an unresolved identity safety hold';
 end if;
 return new;
end $$;
revoke all on function public.gs_credit_authorization_block_historical_identity_hold()
 from public,anon,authenticated;
drop trigger if exists gs_credit_authorization_historical_hold_guard
 on public.gs_credit_customer_authorization_requests;
create trigger gs_credit_authorization_historical_hold_guard
before insert or update of account_id,review_id,registry_id
on public.gs_credit_customer_authorization_requests
for each row execute function public.gs_credit_authorization_block_historical_identity_hold();

-- Minimal staff diagnostics: do not expose customer dispute text.
create or replace function public.gs_staff_credit_authorization_identity_hold_check(p_account_id uuid)
returns table(blocked boolean,hold_count bigint,explanation text)
language plpgsql security definer set search_path='' as $$
declare v_customer_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 select a.customer_id into v_customer_id from public.gs_credit_accounts a where a.id=p_account_id;
 if v_customer_id is null then raise exception 'Credit account not found'; end if;
 return query
 select count(*)>0,count(*),
 case when count(*)>0 then
  'Credit authorization blocked: unresolved historical identity safety hold'
 else 'No historical hold found; customer consent and payment authorization remain unverified'
 end::text
 from public.gs_credit_identity_customer_safety_holds h
 join public.gs_credit_identity_onboarding_requests r on r.id=h.onboarding_request_id
 where r.customer_id=v_customer_id;
end $$;
revoke all on function public.gs_staff_credit_authorization_identity_hold_check(uuid)
 from public,anon;
grant execute on function public.gs_staff_credit_authorization_identity_hold_check(uuid)
 to authenticated;
