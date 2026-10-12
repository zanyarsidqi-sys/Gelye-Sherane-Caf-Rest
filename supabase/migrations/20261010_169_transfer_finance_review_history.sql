-- Upgrade 169: permission-checked, read-only review audit history.
create or replace function public.gs_list_table_transfer_finance_reviews(
 p_request_id bigint)
returns table (
 review_id bigint, reviewed_by uuid, reviewed_at timestamptz,
 review_ready boolean, blocker_codes text[], requested_value_iqd bigint,
 request_status text, outcome text, execution_permitted boolean
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null
   or not public.gs_can_access('invoices_payments','can_view')
   or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Finance review history permission denied';
 end if;
 if p_request_id is null then raise exception 'Request ID required'; end if;
 if not exists (select 1 from public.gs_table_bill_transfer_requests r
   where r.id=p_request_id) then
   raise exception 'Transfer request not found';
 end if;
 return query
 select h.id,h.reviewed_by,h.reviewed_at,h.review_ready,h.blocker_codes,
  h.requested_value_iqd,h.request_status,h.outcome,h.execution_permitted
 from public.gs_table_transfer_finance_reviews h
 where h.request_id=p_request_id
 order by h.reviewed_at desc,h.id desc limit 100;
end; $$;
revoke all on function public.gs_list_table_transfer_finance_reviews(bigint)
 from public,anon;
grant execute on function public.gs_list_table_transfer_finance_reviews(bigint)
 to authenticated;
