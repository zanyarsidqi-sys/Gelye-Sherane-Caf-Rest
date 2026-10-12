-- Upgrade 509: retrieve the current editable instruction value without broad table SELECT.
create or replace function public.gs_staff_table_item_instructions(p_order_item_id bigint)
returns text language plpgsql stable security definer set search_path = '' as $$
declare v_text text;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_order_item_id is null or p_order_item_id <= 0 then
  raise exception 'Invalid item';
 end if;
 select i.preparation_instructions into v_text
 from public.gs_order_items i
 join public.gs_orders o on o.id=i.order_id
 join public.gs_table_visits v on v.id=o.table_visit_id
 where i.id=p_order_item_id and o.is_motel=false
   and o.status='new' and v.status='open'
   and coalesce((select f.status from public.gs_table_item_fulfillment f
                 where f.order_item_id=i.id),'not_accepted')='not_accepted';
 if not found then raise exception 'Item is not eligible for instruction editing'; end if;
 return v_text;
end $$;
revoke all on function public.gs_staff_table_item_instructions(bigint) from public,anon;
grant execute on function public.gs_staff_table_item_instructions(bigint) to authenticated;
