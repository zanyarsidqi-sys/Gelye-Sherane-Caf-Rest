-- Upgrade 404: staff credit verification review and audited cancellation.
-- Pending requests are not payment approvals and cannot debit an account.
create or replace function public.gs_staff_cancel_motel_credit_verification(
 p_request_id uuid, p_reason text)
returns table(request_id uuid, request_status text, cancelled_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare q public.gs_motel_credit_verification_requests%rowtype;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Finance editor required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 5 and 500
 then raise exception 'Cancellation reason must be 5-500 characters'; end if;
 select * into q from public.gs_motel_credit_verification_requests
 where id=p_request_id for update;
 if not found then raise exception 'Credit verification request not found'; end if;
 if q.status <> 'pending' then raise exception 'Only pending requests can be cancelled'; end if;
 update public.gs_motel_credit_verification_requests
 set status='cancelled', cancelled_by=auth.uid(), cancelled_at=now(),
 cancellation_reason=btrim(p_reason) where id=q.id returning * into q;
 return query select q.id,q.status,q.cancelled_at;
end $$;
revoke all on function public.gs_staff_cancel_motel_credit_verification(uuid,text) from public,anon;
grant execute on function public.gs_staff_cancel_motel_credit_verification(uuid,text) to authenticated;

-- The return columns changed since Upgrade 403; PostgreSQL requires dropping the old signature.
drop function if exists public.gs_staff_list_motel_credit_verifications(uuid);
create function public.gs_staff_list_motel_credit_verifications(p_intent_id uuid)
returns table(request_id uuid,request_status text,amount_iqd bigint,
 account_label text,requested_by uuid,requested_at timestamptz,
 cancelled_by uuid,cancelled_at timestamptz,cancellation_reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Finance viewer required'; end if;
 return query select q.id,q.status,q.amount_iqd,a.display_label,
 q.requested_by,q.requested_at,q.cancelled_by,q.cancelled_at,q.cancellation_reason
 from public.gs_motel_credit_verification_requests q
 join public.gs_motel_credit_barcode_registry a on a.id=q.registry_id
 where q.intent_id=p_intent_id order by q.requested_at desc;
end $$;
revoke all on function public.gs_staff_list_motel_credit_verifications(uuid) from public,anon;
grant execute on function public.gs_staff_list_motel_credit_verifications(uuid) to authenticated;
