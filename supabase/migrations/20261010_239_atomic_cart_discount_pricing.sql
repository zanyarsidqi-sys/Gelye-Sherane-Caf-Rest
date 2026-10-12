-- Upgrade 239: Server-authoritative discount pricing for atomic cart orders.
-- Review on staging before deployment. Admin configuration comes from migration 237.
-- Owner prices are optional but required if Owner Mode is selected.
alter table public.gs_menu_products add column if not exists owner_price_iqd bigint;
alter table public.gs_menu_products drop constraint if exists gs_owner_price_nonnegative;
alter table public.gs_menu_products add constraint gs_owner_price_nonnegative check (owner_price_iqd is null or owner_price_iqd >= 0);
alter table public.gs_order_items add column if not exists original_unit_price_iqd bigint;
alter table public.gs_order_items add column if not exists discount_per_unit_iqd bigint not null default 0;
alter table public.gs_order_items add column if not exists discount_mode_id bigint references public.gs_cafe_discount_modes(id);
alter table public.gs_order_items add constraint gs_discount_per_unit_nonnegative check (discount_per_unit_iqd >= 0);
-- The same barcode resolves one product; server determines its effective price.
create or replace function public.gs_create_cart_order(
  p_destination text, p_is_motel boolean, p_table_number integer, p_items jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
 v_uid uuid := auth.uid(); v_tourism boolean; v_order bigint;
 v_line jsonb; v_id bigint; v_qty integer; v_base bigint; v_final bigint;
 v_discount bigint; v_cfg public.gs_cafe_discount_modes%rowtype;
 v_normal bigint; v_tourism_price bigint; v_owner bigint; v_scope text; v_ref text;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if p_is_motel is null then raise exception 'Order type required'; end if;
 if not public.gs_can_access(case when p_is_motel then 'motel_orders' else 'table_orders' end,'can_create')
 then raise exception 'Not authorized'; end if;
 if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 100
 then raise exception 'Cart must contain 1–100 lines'; end if;
 if p_is_motel then
  if p_table_number is not null or p_destination is null or length(trim(p_destination)) not between 1 and 120
  then raise exception 'Invalid motel destination'; end if;
  v_tourism := true; v_scope := 'motel'; v_ref := trim(p_destination);
 else
  if p_table_number is null or p_table_number < 1 then raise exception 'Select a table'; end if;
  select tourism_mode into v_tourism from public.gs_cafe_tables
   where table_number=p_table_number and occupied=true for update;
  if not found then raise exception 'Table unavailable'; end if;
  v_scope := 'table'; v_ref := p_table_number::text;
 end if;
 select * into v_cfg from public.gs_cafe_discount_modes
 where scope=v_scope and scope_reference=v_ref and is_active=true for share;
 insert into public.gs_orders(created_by,destination,is_motel,tourism_mode)
 values(v_uid,v_ref,p_is_motel,v_tourism) returning id into v_order;
 for v_line in select value from jsonb_array_elements(p_items) loop
  if jsonb_typeof(v_line)<>'object' or not (v_line ? 'product_id' and v_line ? 'quantity')
   or jsonb_typeof(v_line->'product_id')<>'number' or jsonb_typeof(v_line->'quantity')<>'number'
  then raise exception 'Invalid cart item'; end if;
  begin
   v_id := (v_line->>'product_id')::bigint;
   v_qty := (v_line->>'quantity')::integer;
  exception when invalid_text_representation or numeric_value_out_of_range then
   raise exception 'Invalid product or quantity';
  end;
  if v_id<=0 or v_qty not between 1 and 999 then raise exception 'Invalid quantity'; end if;
  select normal_price_iqd,tourism_price_iqd,owner_price_iqd
   into v_normal,v_tourism_price,v_owner from public.gs_menu_products
   where id=v_id and is_active=true;
  if not found then raise exception 'Product unavailable'; end if;
  if v_cfg.id is not null and v_cfg.base_mode='owner' then
   if v_owner is null then raise exception 'Owner price not configured for product %',v_id; end if;
   v_base:=v_owner;
  elsif v_cfg.id is not null and v_cfg.base_mode='tourism' then v_base:=v_tourism_price;
  elsif v_cfg.id is not null and v_cfg.base_mode='normal' then v_base:=v_normal;
  else v_base:=case when v_tourism then v_tourism_price else v_normal end;
  end if;
  v_discount:=0;
  if v_cfg.id is not null then
   if v_cfg.discount_type='percent' then
    v_discount:=round(v_base::numeric * v_cfg.discount_value / 100)::bigint;
   else v_discount:=v_cfg.discount_value::bigint; end if;
   v_discount:=least(v_base,greatest(0,v_discount));
  end if;
  v_final:=v_base-v_discount;
  insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd,
   original_unit_price_iqd,discount_per_unit_iqd,discount_mode_id)
  values(v_order,v_id,v_qty,v_final,v_base,v_discount,v_cfg.id);
 end loop;
 return v_order;
end; $$;
revoke all on function public.gs_create_cart_order(text,boolean,integer,jsonb) from public,anon;
grant execute on function public.gs_create_cart_order(text,boolean,integer,jsonb) to authenticated;
