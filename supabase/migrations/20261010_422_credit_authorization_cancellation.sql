-- Upgrade 422: secure cancellation of outstanding authorization requests.
-- This does NOT constitute customer consent and does not authorize a debit.
alter table public.gs_credit_customer_authorization_requests
 drop constraint if exists gs_credit_customer_authorization_requests_status_check;
alter table public.gs_credit_customer_authorization_requests
 add constraint gs_credit_customer_authorization_requests_status_check
 check(status in ('requested','cancelled'));
alter table public.gs_credit_customer_authorization_requests
 add column if not exists cancelled_by uuid references auth.users(id),
 add column if not exists cancelled_at timestamptz,
 add column if not exists cancellation_reason text;
alter table public.gs_credit_customer_authorization_requests
 drop constraint if exists gs_credit_authorization_cancel_consistency;
alter table public.gs_credit_customer_authorization_requests
 add constraint gs_credit_authorization_cancel_consistency check(
  (status='requested' and cancelled_by is null and cancelled_at is null and cancellation_reason is null)
  or (status='cancelled' and cancelled_by is not null and cancelled_at is not null
      and length(btrim(cancellation_reason)) between 10 and 1000));
create or replace function public.gs_staff_cancel_credit_customer_authorization(
 p_request_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_customer_authorization_requests%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 10 and 1000
 then raise exception 'Cancellation reason must be 10-1000 characters'; end if;
 select * into r from public.gs_credit_customer_authorization_requests
 where id=p_request_id for update;
 if not found or r.status<>'requested' then
  raise exception 'Only outstanding authorization requests may be cancelled'; end if;
 update public.gs_credit_customer_authorization_requests
 set status='cancelled',cancelled_by=auth.uid(),cancelled_at=now(),
 cancellation_reason=btrim(p_reason) where id=r.id;
end $$;
revoke all on function public.gs_staff_cancel_credit_customer_authorization(uuid,text) from public,anon;
grant execute on function public.gs_staff_cancel_credit_customer_authorization(uuid,text) to authenticated;

-- Separate v2 read function preserves the original RPC return signature.
create function public.gs_staff_list_credit_customer_authorizations_v2(p_review_id uuid)
returns table(request_id uuid,invoice_reference text,amount_iqd bigint,channel text,
 status text,note text,requested_by uuid,requested_at timestamptz,
 cancelled_by uuid,cancelled_at timestamptz,cancellation_reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select q.id,q.invoice_reference,q.amount_iqd,q.channel,q.status,
 q.note,q.requested_by,q.requested_at,q.cancelled_by,q.cancelled_at,q.cancellation_reason
 from public.gs_credit_customer_authorization_requests q
 where q.review_id=p_review_id order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_customer_authorizations_v2(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_customer_authorizations_v2(uuid) to authenticated;
