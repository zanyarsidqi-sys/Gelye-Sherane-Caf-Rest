-- Upgrade 438: fail-closed identity approval readiness. Does not verify identity.
create or replace function public.gs_staff_credit_identity_approval_readiness(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
 v_response text; v_review public.gs_credit_identity_onboarding_evidence_reviews%rowtype;
 v_conflict boolean;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id;
 if not found then raise exception 'Onboarding request not found'; end if;
 select a.response into v_response from public.gs_credit_identity_onboarding_acknowledgements a
 where a.onboarding_request_id=r.id;
 select * into v_review from public.gs_credit_identity_onboarding_evidence_reviews e
 where e.onboarding_request_id=r.id order by e.reviewed_at desc,e.id desc limit 1;
 select exists(select 1 from public.gs_credit_customer_auth_bindings b
 where b.status='verified' and (b.customer_id=r.customer_id or b.auth_user_id=r.auth_user_id)) into v_conflict;
 return query select 'onboarding_request'::text,
 case when r.status='pending' then 'ready' else 'blocked' end::text,
 ('Request status: '||r.status)::text;
 return query select 'customer_response'::text,
 case when v_response='acknowledged' then 'acknowledged_not_verified' else 'blocked' end::text,
 'Customer acknowledgement does not establish legal identity or credit consent'::text;
 return query select 'independent_evidence_review'::text,
 case when v_review.id is not null and v_review.review_outcome='evidence_reviewed'
 and v_review.reviewed_by<>r.requested_by then 'reviewed_not_verified' else 'blocked' end::text,
 'Independent evidence review is necessary but not sufficient for identity verification'::text;
 return query select 'existing_binding_conflict'::text,
 case when v_conflict then 'blocked' else 'no_verified_conflict' end::text,
 'Verified bindings for the customer or user must not conflict'::text;
 return query select 'authoritative_identity_proof'::text,'not_implemented'::text,
 'Identity ownership proof and independent final approval are not connected'::text;
 return query select 'identity_approval'::text,'blocked'::text,
 'This diagnostic cannot approve a binding or authorize a credit payment'::text;
end $$;
revoke all on function public.gs_staff_credit_identity_approval_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_approval_readiness(uuid) to authenticated;
