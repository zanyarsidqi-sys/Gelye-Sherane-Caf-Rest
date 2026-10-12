-- Upgrade 561: bind employee approval to the quoted order pricing mode.
-- The order row is locked before validating mode and invoking the existing
-- seven-argument quantity/price-confirming transaction.
create or replace function public.gs_replace_unaccepted_table_item(
 p_order_item_id bigint, p_expected_product_id bigint,
 p_expected_unit_price_iqd bigint, p_new_product_id bigint,
 p_reason text, p_confirmed_new_unit_price_iqd bigint,
 p_expected_quantity integer, p_expected_tourism_mode boolean)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_mode boolean;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_expected_tourism_mode is null then
  raise exception 'Pricing mode confirmation required';
 end if;
 select order_id into v_order_id from public.gs_order_items where id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 select tourism_mode into v_mode from public.gs_orders where id=v_order_id for update;
 if not found or v_mode is distinct from p_expected_tourism_mode then
  raise exception 'Order pricing mode changed; request a fresh quote';
 end if;
 return public.gs_replace_unaccepted_table_item(
  p_order_item_id,p_expected_product_id,p_expected_unit_price_iqd,
  p_new_product_id,p_reason,p_confirmed_new_unit_price_iqd,p_expected_quantity);
end $$;
-- Expose only the mode-, quantity-, and price-confirming endpoint.
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer) from public,anon,authenticated;
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer,boolean) from public,anon,authenticated;
grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer,boolean) to authenticated;
