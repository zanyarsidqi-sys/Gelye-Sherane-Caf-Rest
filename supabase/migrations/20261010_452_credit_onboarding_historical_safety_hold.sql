-- Upgrade 452: prevent re-onboarding to evade a customer safety hold.
-- Safety holds are permanent pending an independently designed dispute-resolution process.
-- No verified identity or credit authorization is created by this migration.
create or replace function public.gs_credit_block_onboarding_after_safety_hold()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' or
    (tg_op='UPDATE' and (new.customer_id is distinct from old.customer_id
                           or new.auth_user_id is distinct from old.auth_user_id)) then
   if exists (
      select 1 from public.gs_credit_identity_customer_safety_holds h
      join public.gs_credit_identity_onboarding_requests r
        on r.id=h.onboarding_request_id
      where r.customer_id=new.customer_id or r.auth_user_id=new.auth_user_id
   ) then
      raise exception 'Identity onboarding blocked: historical customer safety hold requires independent dispute resolution';
   end if;
 end if;
 return new;
end $$;
drop trigger if exists gs_credit_onboarding_historical_hold_guard
 on public.gs_credit_identity_onboarding_requests;
create trigger gs_credit_onboarding_historical_hold_guard
 before insert or update on public.gs_credit_identity_onboarding_requests
 for each row execute function public.gs_credit_block_onboarding_after_safety_hold();

-- Read-only staff diagnostics; do not reveal dispute notes or sensitive evidence.
create or replace function public.gs_staff_credit_onboarding_historical_hold_check(
 p_customer_id uuid,p_auth_user_id uuid)
returns table(blocked boolean,hold_count bigint,explanation text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select count(*)>0,count(*),
  case when count(*)>0 then
   'Historical customer dispute exists; onboarding must not be restarted'
  else 'No historical safety hold found; other identity checks still apply' end::text
 from public.gs_credit_identity_customer_safety_holds h
 join public.gs_credit_identity_onboarding_requests r on r.id=h.onboarding_request_id
 where r.customer_id=p_customer_id or r.auth_user_id=p_auth_user_id;
end $$;
revoke all on function public.gs_staff_credit_onboarding_historical_hold_check(uuid,uuid)
 from public,anon;
grant execute on function public.gs_staff_credit_onboarding_historical_hold_check(uuid,uuid)
 to authenticated;
