-- Upgrade 456: customer-owned, read-only consolidated onboarding and hold status.
-- This does not verify identity, grant consent, or authorize payment.
create or replace function public.gs_credit_my_identity_safety_overview()
returns table(request_id uuid,customer_reference text,request_status text,
 response_status text,hold_active boolean,hold_reason text,hold_created_at timestamptz,
 identity_verified boolean,credit_authorized boolean)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return query
 select r.id,c.customer_reference::text,r.status::text,
 coalesce(a.response,'not_answered')::text,(h.id is not null),h.reason,h.created_at,
 false,false
 from public.gs_credit_identity_onboarding_requests r
 join public.gs_credit_customers c on c.id=r.customer_id
 left join lateral (
  select x.response from public.gs_credit_identity_onboarding_acknowledgements x
  where x.onboarding_request_id=r.id order by x.responded_at desc limit 1
 ) a on true
 left join public.gs_credit_identity_customer_safety_holds h on h.onboarding_request_id=r.id
 where r.auth_user_id=auth.uid()
 order by r.requested_at desc,r.id desc limit 100;
end $$;
revoke all on function public.gs_credit_my_identity_safety_overview() from public,anon;
grant execute on function public.gs_credit_my_identity_safety_overview() to authenticated;
