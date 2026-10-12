-- Deploy after 001 foundation and 016 live tables. This is a new RPC; legacy gs_create_order must be revoked separately.
create or replace function public.gs_create_order_for_destination(
 p_destination text, p_is_motel boolean, p_tourism_mode boolean,
 p_product_id bigint, p_quantity integer, p_table_number integer default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_mode boolean; v_price bigint; v_order bigint;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if not public.gs_can_access(case when p_is_motel then 'motel_orders' else 'table_orders' end, 'can_create')
 then raise exception 'Not authorized'; end if;
 if p_quantity is null or p_quantity not between 1 and 999 then raise exception 'Invalid quantity'; end if;
 if p_is_motel is null then raise exception 'Order type required'; end if;
 if p_is_motel then
   if p_table_number is not null then raise exception 'Motel order cannot specify a cafe table'; end if;
   if p_destination is null or length(trim(p_destination)) not between 1 and 120 then raise exception 'Invalid motel destination'; end if;
   v_mode := true;
 else
   if p_table_number is null or p_table_number < 1 then raise exception 'Select a configured table'; end if;
   select tourism_mode into v_mode from public.gs_cafe_tables
   where table_number=p_table_number and occupied=true for update;
   if not found then raise exception 'Table is not occupied or not configured'; end if;
 end if;
 select case when v_mode then tourism_price_iqd else normal_price_iqd end into v_price
 from public.gs_menu_products where id=p_product_id and is_active=true;
 if not found then raise exception 'Product unavailable'; end if;
 insert into public.gs_orders(created_by,destination,is_motel,tourism_mode)
 values(v_uid,case when p_is_motel then trim(p_destination) else p_table_number::text end,p_is_motel,v_mode)
 returning id into v_order;
 insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd)
 values(v_order,p_product_id,p_quantity,v_price);
 return v_order;
end;$$;
revoke all on function public.gs_create_order_for_destination(text,boolean,boolean,bigint,integer,integer) from public;
grant execute on function public.gs_create_order_for_destination(text,boolean,boolean,bigint,integer,integer) to authenticated;
-- Close the old RPC bypass, after migrating every caller to the new function.
revoke execute on function public.gs_create_order(text,boolean,boolean,bigint,integer) from authenticated;
