-- Upgrade 440: append-only external verification evidence intake, not identity approval.
create table if not exists public.gs_credit_identity_external_verification_evidence (
 id uuid primary key default gen_random_uuid(),
 onboarding_request_id uuid not null references public.gs_credit_identity_onboarding_requests(id),
 assessment_id uuid not null references public.gs_credit_identity_final_assessments(id),
 provider_name text not null check(length(btrim(provider_name)) between 3 and 120),
 evidence_reference text not null check(length(btrim(evidence_reference)) between 8 and 250),
 evidence_note text not null check(length(btrim(evidence_note)) between 15 and 1000),
 submitted_by uuid not null references auth.users(id),
 submitted_at timestamptz not null default now(),
 verification_status text not null default 'unverified' check(verification_status='unverified')
);
create unique index if not exists gs_credit_external_evidence_unique_reference
 on public.gs_credit_identity_external_verification_evidence(onboarding_request_id,provider_name,evidence_reference);
alter table public.gs_credit_identity_external_verification_evidence enable row level security;
revoke all on public.gs_credit_identity_external_verification_evidence from public,anon,authenticated;
create or replace function public.gs_staff_submit_credit_identity_external_evidence(
 p_request_id uuid,p_provider_name text,p_evidence_reference text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
 a public.gs_credit_identity_final_assessments%rowtype; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor permission required'; end if;
 if p_provider_name is null or length(btrim(p_provider_name)) not between 3 and 120
 or p_evidence_reference is null or length(btrim(p_evidence_reference)) not between 8 and 250
 or p_note is null or length(btrim(p_note)) not between 15 and 1000
 then raise exception 'Provider, evidence reference and detailed note required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Pending onboarding request required'; end if;
 if exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements k
 where k.onboarding_request_id=r.id and k.response='disputed')
 then raise exception 'Customer disputed onboarding; evidence intake blocked'; end if;
 select * into a from public.gs_credit_identity_final_assessments
 where onboarding_request_id=r.id order by assessed_at desc,id desc limit 1;
 if a.id is null or a.assessment<>'requires_external_verification'
 then raise exception 'External verification assessment required'; end if;
 insert into public.gs_credit_identity_external_verification_evidence
 (onboarding_request_id,assessment_id,provider_name,evidence_reference,evidence_note,submitted_by)
 values(r.id,a.id,btrim(p_provider_name),btrim(p_evidence_reference),btrim(p_note),auth.uid())
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_submit_credit_identity_external_evidence(uuid,text,text,text) from public,anon;
grant execute on function public.gs_staff_submit_credit_identity_external_evidence(uuid,text,text,text) to authenticated;
create or replace function public.gs_staff_list_credit_identity_external_evidence(p_request_id uuid)
returns table(evidence_id uuid,provider_name text,evidence_reference text,evidence_note text,
 submitted_by uuid,submitted_at timestamptz,verification_status text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 return query select e.id,e.provider_name,e.evidence_reference,e.evidence_note,
 e.submitted_by,e.submitted_at,e.verification_status
 from public.gs_credit_identity_external_verification_evidence e
 where e.onboarding_request_id=p_request_id order by e.submitted_at desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_identity_external_evidence(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_external_evidence(uuid) to authenticated;
-- No external provider has been integrated. Evidence references remain unverified.
-- No verified customer binding, consent, or credit debit can be created here.
