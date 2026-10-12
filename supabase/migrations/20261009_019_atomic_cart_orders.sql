-- Deploy after migrations 001, 016, 017 and 018. Review on staging first.
create or replace function public.gs_create_cart_order(
  p_destination text, p_is_motel boolean, p_table_number integer, p_items jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); v_mode boolean; v_order bigint;
  v_line jsonb; v_id bigint; v_qty integer; v_price bigint;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_is_motel is null then raise exception 'Order type required'; end if;
  if not public.gs_can_access(case when p_is_motel then 'motel_orders' else 'table_orders' end, 'can_create')
    then raise exception 'Not authorized'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 100
    then raise exception 'Cart must have 1–100 lines'; end if;
  if p_is_motel then
    if p_table_number is not null then raise exception 'Motel order cannot select cafe table'; end if;
    if p_destination is null or length(trim(p_destination)) not between 1 and 120
      then raise exception 'Invalid motel destination'; end if;
    v_mode := true;
  else
    if p_table_number is null or p_table_number < 1 then raise exception 'Select a table'; end if;
    select tourism_mode into v_mode from public.gs_cafe_tables
      where table_number = p_table_number and occupied = true for update;
    if not found then raise exception 'Table unavailable'; end if;
  end if;
  -- All validations and inserts are part of a single PostgreSQL transaction.
  insert into public.gs_orders(created_by,destination,is_motel,tourism_mode)
  values(v_uid,case when p_is_motel then trim(p_destination) else p_table_number::text end,p_is_motel,v_mode)
  returning id into v_order;
  for v_line in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_line) <> 'object' or not (v_line ? 'product_id' and v_line ? 'quantity')
       or jsonb_typeof(v_line->'product_id') <> 'number' or jsonb_typeof(v_line->'quantity') <> 'number'
       then raise exception 'Invalid cart item'; end if;
    begin
      v_id := (v_line->>'product_id')::bigint;
      v_qty := (v_line->>'quantity')::integer;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'Invalid product or quantity';
    end;
    if v_id <= 0 or v_qty not between 1 and 999 then raise exception 'Invalid quantity'; end if;
    select case when v_mode then tourism_price_iqd else normal_price_iqd end
      into v_price from public.gs_menu_products where id = v_id and is_active = true;
    if not found then raise exception 'Product unavailable'; end if;
    insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd)
      values(v_order,v_id,v_qty,v_price);
  end loop;
  return v_order;
end; $$;
revoke all on function public.gs_create_cart_order(text,boolean,integer,jsonb) from public;
grant execute on function public.gs_create_cart_order(text,boolean,integer,jsonb) to authenticated;
