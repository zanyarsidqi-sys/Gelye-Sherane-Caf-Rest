-- Upgrade 449: enforce customer safety holds at every identity evidence/assessment write.
-- Lock the parent onboarding row so hold creation and staff reviews serialize safely.
create or replace function public.gs_credit_guard_onboarding_safety_hold()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_request_id uuid;
begin
 v_request_id := new.onboarding_request_id;
 if v_request_id is null then raise exception 'Missing onboarding request'; end if;
 perform 1 from public.gs_credit_identity_onboarding_requests
 where id=v_request_id for update;
 if not found then raise exception 'Onboarding request not found'; end if;
 if exists (
   select 1 from public.gs_credit_identity_customer_safety_holds h
   where h.onboarding_request_id=v_request_id
 ) then
   raise exception 'Customer safety hold: identity review or evidence submission is blocked';
 end if;
 return new;
end $$;

-- Existing customer hold RPC locks the same onboarding row before inserting a hold.
-- Therefore a review cannot race with hold creation and bypass this check.
drop trigger if exists gs_credit_hold_onboarding_evidence on public.gs_credit_identity_onboarding_evidence_reviews;
create trigger gs_credit_hold_onboarding_evidence before insert or update
 on public.gs_credit_identity_onboarding_evidence_reviews for each row
 execute function public.gs_credit_guard_onboarding_safety_hold();

drop trigger if exists gs_credit_hold_final_assessment on public.gs_credit_identity_final_assessments;
create trigger gs_credit_hold_final_assessment before insert or update
 on public.gs_credit_identity_final_assessments for each row
 execute function public.gs_credit_guard_onboarding_safety_hold();

drop trigger if exists gs_credit_hold_external_evidence on public.gs_credit_identity_external_verification_evidence;
create trigger gs_credit_hold_external_evidence before insert or update
 on public.gs_credit_identity_external_verification_evidence for each row
 execute function public.gs_credit_guard_onboarding_safety_hold();

drop trigger if exists gs_credit_hold_external_review_all on public.gs_credit_identity_external_evidence_reviews;
create trigger gs_credit_hold_external_review_all before insert or update
 on public.gs_credit_identity_external_evidence_reviews for each row
 execute function public.gs_credit_guard_onboarding_safety_hold();

-- No staff RPC can lift a customer hold. No identity activation or credit debit enabled.
