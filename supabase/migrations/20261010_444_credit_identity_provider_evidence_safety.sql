-- Upgrade 444: fail-closed external identity evidence safety inspection.
-- No staff-entered reference can be mistaken for authenticated provider proof.
create or replace function public.gs_staff_credit_identity_evidence_safety(p_request_id uuid)
returns table(evidence_id uuid, provider_name text, submitted_at timestamptz,
 review_outcome text, safety_status text, explanation text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 if not exists(select 1 from public.gs_credit_identity_onboarding_requests r where r.id=p_request_id)
 then raise exception 'Onboarding request not found'; end if;
 return query
 select e.id,e.provider_name,e.submitted_at,
 coalesce(v.outcome,'not_reviewed')::text,
 'provider_unverified'::text,
 'Manual reference and employee review do not authenticate a provider response; identity activation blocked'::text
 from public.gs_credit_identity_external_verification_evidence e
 left join public.gs_credit_identity_external_evidence_reviews v on v.evidence_id=e.id
 where e.onboarding_request_id=p_request_id
 order by e.submitted_at desc,e.id desc limit 100;
end $$;
revoke all on function public.gs_staff_credit_identity_evidence_safety(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_evidence_safety(uuid) to authenticated;
