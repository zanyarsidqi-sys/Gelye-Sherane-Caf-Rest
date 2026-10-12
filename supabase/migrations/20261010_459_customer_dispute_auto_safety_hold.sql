-- Upgrade 459: disputed customer onboarding responses create an irreversible safety hold.
-- A dispute is NOT payment consent or identity verification.
-- Backfill historical disputes so earlier responses receive the same protection.
insert into public.gs_credit_identity_customer_safety_holds
  (onboarding_request_id,auth_user_id,reason,created_at)
select a.onboarding_request_id,a.auth_user_id,
  'Customer disputed the identity onboarding request',a.responded_at
from public.gs_credit_identity_onboarding_acknowledgements a
where a.response='disputed'
on conflict (onboarding_request_id) do nothing;

create or replace function public.gs_credit_respond_to_identity_onboarding(
 p_request_id uuid,p_response text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_response is null or p_response not in ('acknowledged','disputed') then
  raise exception 'Response must be acknowledged or disputed'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests
 where id=p_request_id for update;
 if not found or r.status<>'pending' or r.auth_user_id<>auth.uid() then
  raise exception 'No pending onboarding request for current user'; end if;
 if exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements
   where onboarding_request_id=p_request_id) then
  raise exception 'Response already recorded; contact staff for correction'; end if;
 if p_response='acknowledged' and exists (
   select 1 from public.gs_credit_identity_customer_safety_holds h
   where h.onboarding_request_id=p_request_id) then
  raise exception 'Customer safety hold prevents acknowledgement'; end if;
 insert into public.gs_credit_identity_onboarding_acknowledgements
 (onboarding_request_id,auth_user_id,response)
 values(r.id,auth.uid(),p_response) returning id into v_id;
 if p_response='disputed' then
  insert into public.gs_credit_identity_customer_safety_holds
   (onboarding_request_id,auth_user_id,reason)
  values(r.id,auth.uid(),'Customer disputed the identity onboarding request')
  on conflict (onboarding_request_id) do nothing;
 end if;
 return v_id;
end $$;
revoke all on function public.gs_credit_respond_to_identity_onboarding(uuid,text) from public,anon;
grant execute on function public.gs_credit_respond_to_identity_onboarding(uuid,text) to authenticated;
