-- Upgrade 463: harden customer authorization visibility and show effective expiry state.
-- Read-only. No customer consent, identity activation, or balance mutation.
create or replace function public.gs_credit_my_authorization_requests()
returns table(invoice_reference text, amount_iqd bigint, request_status text,
 requested_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_customer_id uuid;
begin
 if auth.uid() is null then raise exception 'Customer authentication required'; end if;
 select b.customer_id into v_customer_id
 from public.gs_credit_customer_auth_bindings b
 where b.auth_user_id=auth.uid() and b.status='verified'
   and b.verified_at is not null and b.verified_by is not null
 limit 1;
 if v_customer_id is null then return; end if;
 -- Holds are permanent barriers pending independently validated resolution.
 -- Check both the customer and the authenticated user to prevent account switching.
 if exists (
  select 1 from public.gs_credit_identity_customer_safety_holds h
  join public.gs_credit_identity_onboarding_requests r on r.id=h.onboarding_request_id
  where r.customer_id=v_customer_id or h.auth_user_id=auth.uid()
 ) then return; end if;
 return query
 select q.invoice_reference, q.amount_iqd,
   (case when q.cancelled_at is not null then 'cancelled'
         when q.expires_at <= statement_timestamp() then 'expired'
         else q.status end)::text as request_status,
   q.requested_at, q.expires_at
 from public.gs_credit_customer_authorization_requests q
 join public.gs_credit_accounts a on a.id=q.account_id
 where a.customer_id=v_customer_id
 order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_credit_my_authorization_requests() from public,anon;
grant execute on function public.gs_credit_my_authorization_requests() to authenticated;
