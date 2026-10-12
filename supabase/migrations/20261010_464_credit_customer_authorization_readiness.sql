-- Upgrade 464: fail-closed authorization readiness for employee review.
-- Diagnostic only: no consent, approval, identity activation or debit.
create or replace function public.gs_staff_credit_authorization_readiness(p_review_id uuid)
returns table(invoice_reference text, amount_iqd bigint, request_status text,
 identity_verified boolean, historical_safety_hold boolean, eligible_for_consent boolean,
 reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 if p_review_id is null then raise exception 'Review ID required'; end if;
 return query
 select q.invoice_reference, q.amount_iqd,
   (case when q.cancelled_at is not null then 'cancelled'
         when q.expires_at is not null and q.expires_at<=statement_timestamp() then 'expired'
         else q.status end)::text,
   exists(select 1 from public.gs_credit_customer_auth_bindings b
          join public.gs_credit_accounts a on a.customer_id=b.customer_id
          where a.id=q.account_id and b.status='verified'
            and b.verified_at is not null and b.verified_by is not null),
   exists(select 1 from public.gs_credit_identity_customer_safety_holds h
          join public.gs_credit_identity_onboarding_requests o on o.id=h.onboarding_request_id
          join public.gs_credit_accounts a on a.customer_id=o.customer_id
          where a.id=q.account_id),
   false,
   'Customer payment consent and credit debits are not enabled; authoritative identity verification and independent security review required'::text
 from public.gs_credit_customer_authorization_requests q
 where q.review_id=p_review_id
 order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_staff_credit_authorization_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_readiness(uuid) to authenticated;
