-- Upgrade 415: read-only identity/link approval readiness; no account activation.
create or replace function public.gs_staff_credit_link_approval_readiness(p_registry_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare v_link public.gs_credit_account_registry_links%rowtype;
 v_account public.gs_credit_accounts%rowtype;
 v_customer public.gs_credit_customers%rowtype;
 v_registry public.gs_motel_credit_barcode_registry%rowtype;
 v_review public.gs_credit_identity_review_requests%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 select * into v_link from public.gs_credit_account_registry_links where registry_id=p_registry_id;
 if not found then raise exception 'Barcode/account link not found'; end if;
 select * into v_account from public.gs_credit_accounts where id=v_link.account_id;
 select * into v_customer from public.gs_credit_customers where id=v_account.customer_id;
 select * into v_registry from public.gs_motel_credit_barcode_registry where id=v_link.registry_id;
 select * into v_review from public.gs_credit_identity_review_requests
 where registry_id=p_registry_id order by requested_at desc,id desc limit 1;
 return query select 'link_state'::text,
 case when v_link.link_status='pending' then 'pending' else 'blocked' end::text,
 'Pending link must not be treated as verified'::text;
 return query select 'account_reference_match'::text,
 case when v_account.account_reference=v_registry.account_reference then 'pass' else 'blocked' end::text,
 'References match, but this does not prove account ownership'::text;
 return query select 'independent_evidence_review'::text,
 case when v_review.status='reviewed' and v_review.requested_by<>v_review.reviewed_by
 then 'reviewed_not_verified' else 'missing' end::text,
 'Evidence review is not authoritative customer identity verification'::text;
 return query select 'authoritative_identity'::text,'unverified'::text,
 'No authoritative identity validation or customer consent mechanism exists'::text;
 return query select 'customer_status'::text,coalesce(v_customer.verification_status,'missing')::text,
 'Customer verification state is not upgraded by this check'::text;
 return query select 'approval_eligible'::text,'blocked'::text,
 'Do not activate links, accounts, credit limits or credit payments'::text;
end $$;
revoke all on function public.gs_staff_credit_link_approval_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_credit_link_approval_readiness(uuid) to authenticated;
