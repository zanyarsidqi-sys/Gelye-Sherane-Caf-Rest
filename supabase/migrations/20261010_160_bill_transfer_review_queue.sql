-- Upgrade 160: authorized, read-only bill-transfer review queue.
-- Approval and execution are intentionally NOT provided.
create or replace function public.gs_list_table_bill_transfer_reviews()
returns table(request_id bigint, source_visit_id bigint,
 destination_visit_id bigint, request_status text, reason text,
 item_count bigint, requested_value_iqd bigint, requested_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null
  or not public.gs_can_access('table_orders','can_view')
  or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Bill transfer review access denied';
 end if;
 return query
 select r.id, r.source_visit_id, r.destination_visit_id,
  r.status, r.reason, count(ri.id)::bigint,
  coalesce(sum(ri.requested_quantity::bigint * oi.unit_price_iqd),0)::bigint,
  r.created_at
 from public.gs_table_bill_transfer_requests r
 join public.gs_table_bill_transfer_request_items ri on ri.transfer_request_id=r.id
 join public.gs_order_items oi on oi.id=ri.order_item_id
 where r.status='pending'
 group by r.id, r.source_visit_id, r.destination_visit_id,
  r.status, r.reason, r.created_at
 order by r.created_at desc, r.id desc
 limit 100;
end; $$;
revoke all on function public.gs_list_table_bill_transfer_reviews()
 from public,anon;
grant execute on function public.gs_list_table_bill_transfer_reviews()
 to authenticated;
