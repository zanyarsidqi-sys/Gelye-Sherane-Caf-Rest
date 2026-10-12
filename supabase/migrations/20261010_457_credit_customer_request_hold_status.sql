-- Upgrade 457: customer-owned per-request hold status, fail-closed read access.
-- Never exposes another customer's identity information.
create or replace function public.gs_credit_my_identity_request_hold_status(p_request_id uuid)
returns table(request_id uuid,hold_active boolean,reason text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not exists(select 1 from public.gs_credit_identity_onboarding_requests r
               where r.id=p_request_id and r.auth_user_id=auth.uid())
 then raise exception 'Identity onboarding request not found'; end if;
 return query select p_request_id,h.id is not null,h.reason,h.created_at
 from (select 1) s left join public.gs_credit_identity_customer_safety_holds h
 on h.onboarding_request_id=p_request_id and h.auth_user_id=auth.uid();
end $$;
revoke all on function public.gs_credit_my_identity_request_hold_status(uuid) from public,anon;
grant execute on function public.gs_credit_my_identity_request_hold_status(uuid) to authenticated;
