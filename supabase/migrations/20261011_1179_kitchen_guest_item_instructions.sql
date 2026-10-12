-- Upgrade 1179: optional per-item guest identity and preparation notes.
-- Metadata only: financial quantities/prices and table billing are unchanged.
alter table public.gs_order_items
  add column if not exists guest_label text,
  add column if not exists preparation_notes text;
alter table public.gs_order_items
  drop constraint if exists gs_order_item_guest_label_limit;
alter table public.gs_order_items
  add constraint gs_order_item_guest_label_limit
  check (guest_label is null or
    (char_length(guest_label) between 1 and 80 and guest_label = btrim(guest_label)));
alter table public.gs_order_items
  drop constraint if exists gs_order_item_notes_limit;
alter table public.gs_order_items
  add constraint gs_order_item_notes_limit
  check (preparation_notes is null or
    (char_length(preparation_notes) between 1 and 500 and preparation_notes = btrim(preparation_notes)));

-- This controlled staff action cannot alter price, quantity, order or product.
create or replace function public.gs_set_kitchen_item_instructions(
  p_item_id bigint, p_guest_label text, p_preparation_notes text
) returns void language plpgsql security definer set search_path = '' as $$
declare v_status text;
declare v_guest text := nullif(btrim(coalesce(p_guest_label,'')), '');
declare v_notes text := nullif(btrim(coalesce(p_preparation_notes,'')), '');
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
   raise exception 'Table Orders edit permission required';
 end if;
 if p_item_id is null or p_item_id <= 0 or
    char_length(v_guest) > 80 or char_length(v_notes) > 500 then
   raise exception 'Invalid item, guest label, or notes';
 end if;
 select o.status into v_status
 from public.gs_order_items i
 join public.gs_orders o on o.id=i.order_id
 where i.id=p_item_id and not o.is_motel for update of o, i;
 if not found then raise exception 'Table order item not found'; end if;
 if v_status <> 'new' then
   raise exception 'Item instructions can only be edited before order acceptance';
 end if;
 update public.gs_order_items
 set guest_label=v_guest, preparation_notes=v_notes
 where id=p_item_id;
end;
$$;
revoke all on function public.gs_set_kitchen_item_instructions(bigint,text,text) from public,anon;
grant execute on function public.gs_set_kitchen_item_instructions(bigint,text,text) to authenticated;

-- Replace read-only Kitchen RPC with the same fields plus item identity/notes.
drop function if exists public.gs_kitchen_order_item_details(bigint);
create function public.gs_kitchen_order_item_details(p_order_id bigint)
returns table(item_id bigint, product_id bigint, quantity integer, unit_price_iqd bigint,
              line_total_iqd bigint, product_name text, station_name text,
              guest_label text, preparation_notes text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required';
 end if;
 if p_order_id is null or p_order_id <= 0 then
   raise exception 'Valid order required';
 end if;
 return query
   select i.id, i.product_id, i.quantity, i.unit_price_iqd, i.line_total_iqd,
          p.name, coalesce(s.display_name, 'Unassigned preparation station'),
          i.guest_label, i.preparation_notes
   from public.gs_order_items i
   join public.gs_menu_products p on p.id=i.product_id
   left join public.gs_cafe_product_preparation route on route.product_id=i.product_id
   left join public.gs_cafe_preparation_stations s on s.station_key=route.station_key
   where i.order_id=p_order_id
   order by i.id;
end;
$$;
revoke all on function public.gs_kitchen_order_item_details(bigint) from public,anon;
grant execute on function public.gs_kitchen_order_item_details(bigint) to authenticated;
