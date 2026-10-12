-- Upgrade 433: read-only staff onboarding review and audited cancellation.
-- Neither action verifies ownership or grants credit consent.
create or replace function public.gs_staff_list_credit_identity_onboarding(p_status text default 'pending')
returns table(request_id uuid,customer_id uuid,customer_reference text,auth_user_id uuid,
 status text,reason text,requested_by uuid,requested_at timestamptz,
 cancelled_by uuid,cancelled_at timestamptz,cancellation_reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 if p_status not in ('pending','cancelled','all') then raise exception 'Invalid status filter'; end if;
 return query select r.id,r.customer_id,c.customer_reference,r.auth_user_id,
 r.status,r.reason,r.requested_by,r.requested_at,r.cancelled_by,r.cancelled_at,r.cancellation_reason
 from public.gs_credit_identity_onboarding_requests r
 join public.gs_credit_customers c on c.id=r.customer_id
 where p_status='all' or r.status=p_status
 order by r.requested_at desc,r.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_identity_onboarding(text) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_onboarding(text) to authenticated;
create or replace function public.gs_staff_cancel_credit_identity_onboarding(p_request_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 10 and 1000
 then raise exception 'Cancellation reason must contain 10-1000 characters'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests where id=p_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Only pending onboarding requests can be cancelled'; end if;
 update public.gs_credit_identity_onboarding_requests
 set status='cancelled',cancelled_by=auth.uid(),cancelled_at=now(),cancellation_reason=btrim(p_reason)
 where id=p_request_id;
end $$;
revoke all on function public.gs_staff_cancel_credit_identity_onboarding(uuid,text) from public,anon;
grant execute on function public.gs_staff_cancel_credit_identity_onboarding(uuid,text) to authenticated;
