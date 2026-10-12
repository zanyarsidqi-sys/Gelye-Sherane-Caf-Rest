-- Upgrade 441: independent review of unverified external evidence.
-- Reviews are assessments of documentation only, NEVER authoritative identity verification.
create table if not exists public.gs_credit_identity_external_evidence_reviews (
 id uuid primary key default gen_random_uuid(),
 evidence_id uuid not null references public.gs_credit_identity_external_verification_evidence(id),
 onboarding_request_id uuid not null references public.gs_credit_identity_onboarding_requests(id),
 outcome text not null check(outcome in ('documentation_reviewed','needs_correction','rejected')),
 review_note text not null check(length(btrim(review_note)) between 15 and 1000),
 reviewed_by uuid not null references auth.users(id),
 reviewed_at timestamptz not null default now()
);
create unique index if not exists gs_credit_external_review_one_per_evidence
 on public.gs_credit_identity_external_evidence_reviews(evidence_id);
alter table public.gs_credit_identity_external_evidence_reviews enable row level security;
revoke all on public.gs_credit_identity_external_evidence_reviews from public,anon,authenticated;

create or replace function public.gs_staff_review_credit_identity_external_evidence(
 p_evidence_id uuid,p_outcome text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare e public.gs_credit_identity_external_verification_evidence%rowtype;
 r public.gs_credit_identity_onboarding_requests%rowtype;
 a public.gs_credit_identity_final_assessments%rowtype;
 v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor permission required'; end if;
 if p_outcome is null or p_outcome not in ('documentation_reviewed','needs_correction','rejected')
 or p_note is null or length(btrim(p_note)) not between 15 and 1000
 then raise exception 'Valid outcome and 15-1000 character review note required'; end if;
 select * into e from public.gs_credit_identity_external_verification_evidence
 where id=p_evidence_id for update;
 if not found then raise exception 'Evidence not found'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests
 where id=e.onboarding_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Pending onboarding required'; end if;
 select * into a from public.gs_credit_identity_final_assessments where id=e.assessment_id;
 if a.id is null or a.onboarding_request_id<>r.id or a.assessment<>'requires_external_verification'
 then raise exception 'External evidence assessment is invalid'; end if;
 if auth.uid() in (e.submitted_by,r.requested_by,a.assessed_by)
 then raise exception 'Reviewer must be independent of submitter, requester and assessor'; end if;
 if exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements k
 where k.onboarding_request_id=r.id and k.response='disputed')
 then raise exception 'Customer disputed onboarding'; end if;
 if exists(select 1 from public.gs_credit_identity_external_evidence_reviews v where v.evidence_id=e.id)
 then raise exception 'Evidence already reviewed'; end if;
 insert into public.gs_credit_identity_external_evidence_reviews
 (evidence_id,onboarding_request_id,outcome,review_note,reviewed_by)
 values(e.id,r.id,p_outcome,btrim(p_note),auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_review_credit_identity_external_evidence(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_review_credit_identity_external_evidence(uuid,text,text) to authenticated;

create or replace function public.gs_staff_list_credit_identity_external_evidence_reviews(p_request_id uuid)
returns table(review_id uuid,evidence_id uuid,outcome text,review_note text,reviewed_by uuid,reviewed_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 return query select v.id,v.evidence_id,v.outcome,v.review_note,v.reviewed_by,v.reviewed_at
 from public.gs_credit_identity_external_evidence_reviews v
 where v.onboarding_request_id=p_request_id order by v.reviewed_at desc,v.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_identity_external_evidence_reviews(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_external_evidence_reviews(uuid) to authenticated;
-- No verified identity binding, customer payment consent or credit debit.
