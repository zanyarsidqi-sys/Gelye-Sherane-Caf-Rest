-- Upgrade 439: independent final identity assessment; NO verified binding is issued.
create table if not exists public.gs_credit_identity_final_assessments (
 id uuid primary key default gen_random_uuid(),
 onboarding_request_id uuid not null references public.gs_credit_identity_onboarding_requests(id),
 evidence_review_id uuid not null references public.gs_credit_identity_onboarding_evidence_reviews(id),
 assessment text not null check (assessment in ('requires_external_verification','rejected')),
 assessment_note text not null check(length(btrim(assessment_note)) between 15 and 1000),
 assessed_by uuid not null references auth.users(id),
 assessed_at timestamptz not null default now()
);
create unique index if not exists gs_credit_identity_final_one_assessment
 on public.gs_credit_identity_final_assessments(onboarding_request_id);
alter table public.gs_credit_identity_final_assessments enable row level security;
revoke all on public.gs_credit_identity_final_assessments from public,anon,authenticated;

create or replace function public.gs_staff_assess_credit_identity_onboarding(
 p_request_id uuid,p_assessment text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
 e public.gs_credit_identity_onboarding_evidence_reviews%rowtype;
 v_response text; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor permission required'; end if;
 if p_assessment is null or p_assessment not in ('requires_external_verification','rejected')
 or p_note is null or length(btrim(p_note)) not between 15 and 1000
 then raise exception 'Valid assessment and 15-1000 character note required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Pending onboarding required'; end if;
 if auth.uid()=r.requested_by then raise exception 'Requester cannot perform final assessment'; end if;
 select a.response into v_response from public.gs_credit_identity_onboarding_acknowledgements a
 where a.onboarding_request_id=r.id;
 if v_response is distinct from 'acknowledged' then raise exception 'Customer acknowledgement required; disputes blocked'; end if;
 select * into e from public.gs_credit_identity_onboarding_evidence_reviews
 where onboarding_request_id=r.id order by reviewed_at desc,id desc limit 1;
 if e.id is null or e.review_outcome<>'evidence_reviewed' then
 raise exception 'Latest evidence must be independently reviewed'; end if;
 if e.reviewed_by=r.requested_by or e.reviewed_by=auth.uid() then
 raise exception 'Final assessor must be separate from requester and evidence reviewer'; end if;
 if exists(select 1 from public.gs_credit_customer_auth_bindings b
 where b.status='verified' and (b.customer_id=r.customer_id or b.auth_user_id=r.auth_user_id))
 then raise exception 'Conflicting verified identity binding'; end if;
 insert into public.gs_credit_identity_final_assessments
 (onboarding_request_id,evidence_review_id,assessment,assessment_note,assessed_by)
 values(r.id,e.id,p_assessment,btrim(p_note),auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_assess_credit_identity_onboarding(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_assess_credit_identity_onboarding(uuid,text,text) to authenticated;

create or replace function public.gs_staff_list_credit_identity_final_assessments(p_request_id uuid)
returns table(assessment_id uuid,assessment text,assessment_note text,assessed_by uuid,
 assessed_at timestamptz,evidence_review_id uuid)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 return query select a.id,a.assessment,a.assessment_note,a.assessed_by,a.assessed_at,a.evidence_review_id
 from public.gs_credit_identity_final_assessments a where a.onboarding_request_id=p_request_id
 order by a.assessed_at desc limit 20;
end $$;
revoke all on function public.gs_staff_list_credit_identity_final_assessments(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_final_assessments(uuid) to authenticated;
-- No approval RPC, binding mutation, customer consent, or credit debit.
