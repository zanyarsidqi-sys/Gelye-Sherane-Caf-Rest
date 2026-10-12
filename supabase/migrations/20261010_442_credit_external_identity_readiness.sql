-- Upgrade 442: independent external-evidence readiness diagnostic.
-- Never infer authoritative identity verification from employee review.
create or replace function public.gs_staff_credit_external_identity_readiness(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
 a public.gs_credit_identity_final_assessments%rowtype;
 e public.gs_credit_identity_external_verification_evidence%rowtype;
 v public.gs_credit_identity_external_evidence_reviews%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 return query select 'onboarding'::text,
   case when r.status='pending' then 'pending' else 'blocked' end::text,
   'Only a pending onboarding request may proceed'::text;
 return query select 'customer_dispute'::text,
   case when exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements k
       where k.onboarding_request_id=r.id and k.response='disputed')
   then 'blocked' else 'no_dispute_recorded' end::text,
   'No dispute does not prove account ownership'::text;
 select * into a from public.gs_credit_identity_final_assessments
 where onboarding_request_id=r.id order by assessed_at desc,id desc limit 1;
 return query select 'independent_assessment'::text,
   case when a.assessment='requires_external_verification' then 'recorded' else 'blocked' end::text,
   'Assessment does not independently verify identity'::text;
 select * into e from public.gs_credit_identity_external_verification_evidence
 where onboarding_request_id=r.id order by submitted_at desc,id desc limit 1;
 return query select 'external_evidence'::text,
   case when e.id is not null then 'submitted_unverified' else 'missing' end::text,
   'Provider evidence is not authenticated by this system'::text;
 if e.id is not null then
  select * into v from public.gs_credit_identity_external_evidence_reviews
  where evidence_id=e.id limit 1;
 end if;
 return query select 'independent_evidence_review'::text,
   case when v.outcome='documentation_reviewed' then 'documentation_reviewed'
        when v.outcome='rejected' then 'rejected'
        when v.outcome='needs_correction' then 'needs_correction'
        else 'missing' end::text,
   'A documentation review is not provider verification'::text;
 return query select 'provider_verification'::text,'not_integrated'::text,
   'No trusted external provider callback or signed verification proof is implemented'::text;
 return query select 'identity_activation'::text,'blocked'::text,
   'No verified binding is activated by this diagnostic'::text;
 return query select 'customer_payment_consent'::text,'blocked'::text,
   'No authenticated consent to an exact invoice and amount has been collected'::text;
 return query select 'credit_debit'::text,'blocked'::text,
   'Credit settlement remains disabled'::text;
end $$;
revoke all on function public.gs_staff_credit_external_identity_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_credit_external_identity_readiness(uuid) to authenticated;
