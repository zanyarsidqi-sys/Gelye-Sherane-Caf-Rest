-- Upgrade 419: fail-closed, read-only credit approval eligibility per identity review.
create or replace function public.gs_staff_credit_identity_review_eligibility(p_review_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
 c public.gs_credit_customers%rowtype;
 b public.gs_motel_credit_barcode_registry%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=p_review_id;
 if not found then raise exception 'Review not found'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=v.registry_id;
 select * into a from public.gs_credit_accounts where id=v.account_id;
 select * into c from public.gs_credit_customers where id=a.customer_id;
 select * into b from public.gs_motel_credit_barcode_registry where id=v.registry_id;
 return query select 'review_integrity'::text,
 case when l.registry_id is not null and l.account_id=v.account_id and a.id=v.account_id
 then 'pass' else 'blocked' end::text,
 'Review, barcode link, and account must refer to the same record'::text;
 return query select 'current_link_state'::text,
 case when l.link_status='pending' then 'pending' else 'blocked' end::text,
 'Revoked or already processed links are not eligible for approval'::text;
 return query select 'account_state'::text,
 case when a.account_status='pending' then 'pending' else 'blocked' end::text,
 'Account must remain pending during independent review'::text;
 return query select 'registry_reference_match'::text,
 case when a.account_reference=b.account_reference then 'pass' else 'blocked' end::text,
 'Matching references are not proof of customer ownership'::text;
 return query select 'independent_review'::text,
 case when v.status='reviewed' and v.reviewed_by is not null and v.reviewed_by<>v.requested_by
 then 'reviewed_not_verified' else 'missing' end::text,
 'A second employee review is required but does not establish identity'::text;
 return query select 'authoritative_identity'::text,'unverified'::text,
 'No identity verification provider or documented legal verification method is connected'::text;
 return query select 'customer_consent'::text,'unverified'::text,
 'No verified customer authorization for credit account activation or charges exists'::text;
 return query select 'approval_eligible'::text,'blocked'::text,
 'Do not activate credit accounts or links based on human evidence review alone'::text;
end $$;
revoke all on function public.gs_staff_credit_identity_review_eligibility(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_review_eligibility(uuid) to authenticated;
