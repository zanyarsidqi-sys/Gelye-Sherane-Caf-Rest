-- Upgrade 446: fail-closed read-only latest-evidence review guard.
-- A reviewed old document must never make a newer unreviewed document look reviewed.
create or replace function public.gs_staff_credit_identity_latest_evidence_guard(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
 e public.gs_credit_identity_external_verification_evidence%rowtype;
 v public.gs_credit_identity_external_evidence_reviews%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 return query select 'onboarding'::text,
 case when r.status='pending' then 'pending' else 'blocked' end::text,
 'Only pending onboarding can be reviewed'::text;
 if exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements k
   where k.onboarding_request_id=r.id and k.response='disputed') then
   return query select 'customer_dispute'::text,'blocked'::text,
     'Customer dispute blocks all further verification activity'::text;
 else
   return query select 'customer_dispute'::text,'no_dispute_recorded'::text,
     'Absence of dispute does not establish identity'::text;
 end if;
 select * into e from public.gs_credit_identity_external_verification_evidence x
 where x.onboarding_request_id=r.id order by x.submitted_at desc,x.id desc limit 1;
 if not found then
   return query select 'latest_evidence'::text,'missing'::text,
     'No external verification evidence has been submitted'::text;
 else
   return query select 'latest_evidence'::text,'submitted_unverified'::text,
     'Latest evidence ID: '||e.id::text;
   select * into v from public.gs_credit_identity_external_evidence_reviews x
   where x.evidence_id=e.id order by x.reviewed_at desc,x.id desc limit 1;
   return query select 'latest_evidence_review'::text,
     case when v.id is null then 'not_reviewed'
          when v.outcome='documentation_reviewed' then 'documentation_only'
          else 'blocked' end::text,
     case when v.id is null then 'Latest submission has no independent review'
          else 'Latest review outcome: '||v.outcome end::text;
 end if;
 return query select 'authoritative_provider_verification'::text,'not_integrated'::text,
   'Staff-supplied evidence is never proof of a verified provider response'::text;
 return query select 'customer_identity_activation'::text,'blocked'::text,
   'Identity cannot be activated by this diagnostic'::text;
 return query select 'customer_payment_consent'::text,'blocked'::text,
   'No authenticated customer payment consent has been recorded'::text;
 return query select 'credit_debit'::text,'blocked'::text,
   'No credit debit or settlement is permitted'::text;
end $$;
revoke all on function public.gs_staff_credit_identity_latest_evidence_guard(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_latest_evidence_guard(uuid) to authenticated;
