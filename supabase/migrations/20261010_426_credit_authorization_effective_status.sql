-- Upgrade 426: effective expiry read, never consent.
create or replace function public.gs_staff_list_credit_customer_authorizations_v3(p_review_id uuid)
returns table(request_id uuid,invoice_reference text,amount_iqd bigint,channel text,
 status text,effective_status text,note text,requested_by uuid,requested_at timestamptz,
 expires_at timestamptz,cancelled_by uuid,cancelled_at timestamptz,cancellation_reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select q.id,q.invoice_reference,q.amount_iqd,q.channel,q.status,
 case when q.status='cancelled' then 'cancelled'
      when q.expires_at<=statement_timestamp() then 'expired'
      else 'awaiting_customer_consent' end::text,
 q.note,q.requested_by,q.requested_at,q.expires_at,q.cancelled_by,q.cancelled_at,q.cancellation_reason
 from public.gs_credit_customer_authorization_requests q where q.review_id=p_review_id
 order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_customer_authorizations_v3(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_customer_authorizations_v3(uuid) to authenticated;
