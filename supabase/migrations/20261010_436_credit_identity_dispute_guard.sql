-- Upgrade 436: disputes block new employee evidence reviews. Customer acknowledgement is not verified identity.
create or replace function public.gs_staff_review_credit_identity_onboarding_evidence(
 p_request_id uuid,p_evidence_reference text,p_review_note text,p_outcome text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_outcome is null or p_outcome not in ('needs_more_evidence','evidence_reviewed','rejected')
 or p_evidence_reference is null or length(btrim(p_evidence_reference)) not between 8 and 500
 or p_review_note is null or length(btrim(p_review_note)) not between 10 and 1000
 then raise exception 'Valid evidence reference, review note and outcome required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Onboarding request is not pending'; end if;
 if r.requested_by=auth.uid() then raise exception 'Independent reviewer required'; end if;
 if exists (select 1 from public.gs_credit_identity_onboarding_acknowledgements a
  where a.onboarding_request_id=p_request_id and a.response='disputed') then
  raise exception 'Customer disputed onboarding; evidence review blocked'; end if;
 insert into public.gs_credit_identity_onboarding_evidence_reviews
 (onboarding_request_id,evidence_reference,review_note,review_outcome,reviewed_by)
 values(p_request_id,btrim(p_evidence_reference),btrim(p_review_note),p_outcome,auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_review_credit_identity_onboarding_evidence(uuid,text,text,text) from public,anon;
grant execute on function public.gs_staff_review_credit_identity_onboarding_evidence(uuid,text,text,text) to authenticated;

create or replace function public.gs_staff_credit_identity_onboarding_dispute_status(p_request_id uuid)
returns table(request_status text,customer_response text,review_allowed boolean,explanation text)
language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype; v_response text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 select a.response into v_response from public.gs_credit_identity_onboarding_acknowledgements a
 where a.onboarding_request_id=p_request_id;
 return query select r.status,v_response,
   (r.status='pending' and v_response is distinct from 'disputed'),
   case when v_response='disputed' then 'Customer disputed this identity association; further evidence review is blocked'
        when r.status<>'pending' then 'Request is no longer pending'
        else 'Evidence review can be recorded by an independent employee; identity is NOT verified' end;
end $$;
revoke all on function public.gs_staff_credit_identity_onboarding_dispute_status(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_onboarding_dispute_status(uuid) to authenticated;
