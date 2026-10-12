-- Upgrade 434: independent staff evidence review, without granting verified identity.
create table if not exists public.gs_credit_identity_onboarding_evidence_reviews (
 id uuid primary key default gen_random_uuid(),
 onboarding_request_id uuid not null references public.gs_credit_identity_onboarding_requests(id),
 evidence_reference text not null check(length(btrim(evidence_reference)) between 8 and 500),
 review_note text not null check(length(btrim(review_note)) between 10 and 1000),
 review_outcome text not null check(review_outcome in ('needs_more_evidence','evidence_reviewed','rejected')),
 reviewed_by uuid not null references auth.users(id),
 reviewed_at timestamptz not null default now()
);
create index if not exists gs_credit_onboarding_evidence_by_request on public.gs_credit_identity_onboarding_evidence_reviews(onboarding_request_id,reviewed_at desc);
alter table public.gs_credit_identity_onboarding_evidence_reviews enable row level security;
revoke all on public.gs_credit_identity_onboarding_evidence_reviews from public,anon,authenticated;
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
 insert into public.gs_credit_identity_onboarding_evidence_reviews
 (onboarding_request_id,evidence_reference,review_note,review_outcome,reviewed_by)
 values(p_request_id,btrim(p_evidence_reference),btrim(p_review_note),p_outcome,auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_review_credit_identity_onboarding_evidence(uuid,text,text,text) from public,anon;
grant execute on function public.gs_staff_review_credit_identity_onboarding_evidence(uuid,text,text,text) to authenticated;
create or replace function public.gs_staff_list_credit_identity_onboarding_evidence(p_request_id uuid)
returns table(review_id uuid,evidence_reference text,review_note text,review_outcome text,reviewed_by uuid,reviewed_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select e.id,e.evidence_reference,e.review_note,e.review_outcome,e.reviewed_by,e.reviewed_at
 from public.gs_credit_identity_onboarding_evidence_reviews e
 where e.onboarding_request_id=p_request_id order by e.reviewed_at desc,e.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_identity_onboarding_evidence(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_onboarding_evidence(uuid) to authenticated;
-- No identity binding update and no consent/credit approval is permitted by these functions.
