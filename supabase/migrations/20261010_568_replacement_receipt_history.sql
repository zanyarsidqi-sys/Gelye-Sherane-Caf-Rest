-- Upgrade 568: bounded, actor-scoped committed replacement history across devices.
-- This endpoint intentionally returns only committed receipts, not in-flight requests.
create or replace function public.gs_table_replacement_receipt_history(p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_rows jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order viewing permission required';
 end if;
 if p_limit is null or p_limit < 1 or p_limit > 50 then
  raise exception 'Receipt history limit must be between 1 and 50';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'request_id', request_id, 'committed_at', created_at,
  'order_item_id', result->'order_item_id',
  'product_id', result->'product_id',
  'difference_iqd', result->'difference_iqd') order by created_at desc, request_id desc), '[]'::jsonb)
 into v_rows from (
  select request_id, created_at, result
  from public.gs_table_replacement_requests
  where actor_id = auth.uid()
  order by created_at desc, request_id desc limit p_limit
 ) receipts;
 return v_rows;
end $$;
revoke all on function public.gs_table_replacement_receipt_history(integer) from public, anon, authenticated;
grant execute on function public.gs_table_replacement_receipt_history(integer) to authenticated;
