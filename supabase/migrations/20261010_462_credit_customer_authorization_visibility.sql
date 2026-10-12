-- Upgrade 462: authenticated customer read-only invoice authorization visibility.
-- A verified identity binding is required. No consent, approval, or debit is created.
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
 limit 1;
 if v_customer_id is null then
   -- Fail closed: unverified/pending identities never see invoice details.
   return;
 end if;
 if exists (
   select 1 from public.gs_credit_identity_customer_safety_holds h
   join public.gs_credit_identity_onboarding_requests r on r.id=h.onboarding_request_id
   where r.customer_id=v_customer_id
 ) then return; end if;
 return query
 select q.invoice_reference,q.amount_iqd,q.status,q.requested_at,
        q.expires_at
 from public.gs_credit_customer_authorization_requests q
 join public.gs_credit_accounts a on a.id=q.account_id
 where a.customer_id=v_customer_id
 order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_credit_my_authorization_requests() from public,anon;
grant execute on function public.gs_credit_my_authorization_requests() to authenticated;
