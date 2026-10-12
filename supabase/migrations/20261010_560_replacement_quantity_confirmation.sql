-- Upgrade 560: require the quoted quantity at commit time.
-- Keep the prior six-argument function internal to preserve dependent SQL.
create or replace function public.gs_replace_unaccepted_table_item(
 p_order_item_id bigint, p_expected_product_id bigint,
 p_expected_unit_price_iqd bigint, p_new_product_id bigint,
 p_reason text, p_confirmed_new_unit_price_iqd bigint,
 p_expected_quantity integer)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_actual_quantity integer;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_expected_quantity is null or p_expected_quantity <= 0 then
  raise exception 'Invalid expected quantity';
 end if;
 select order_id into v_order_id from public.gs_order_items where id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 -- Match the lock order used by the underlying replacement RPC.
 perform 1 from public.gs_orders where id=v_order_id for update;
 select quantity into v_actual_quantity from public.gs_order_items
 where id=p_order_item_id and order_id=v_order_id for update;
 if not found or v_actual_quantity is distinct from p_expected_quantity then
  raise exception 'Order item quantity changed; request a fresh quote';
 end if;
 return public.gs_replace_unaccepted_table_item(
  p_order_item_id,p_expected_product_id,p_expected_unit_price_iqd,
  p_new_product_id,p_reason,p_confirmed_new_unit_price_iqd);
end $$;
-- Only the seven-argument, quantity-confirming endpoint is exposed to staff.
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint) from public,anon,authenticated;
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer) from public,anon,authenticated;
grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer) to authenticated;
