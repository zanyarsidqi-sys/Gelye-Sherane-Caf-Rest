-- Upgrade 180: price-locked menu line draft for table-free counter requests.
-- No charge, inventory deduction, kitchen submission or payment posting.
create table if not exists public.gs_counter_order_request_items (
 id bigint generated always as identity primary key,
 request_id bigint not null references public.gs_counter_order_requests(id) on delete restrict,
 product_id bigint not null references public.gs_menu_products(id),
 product_name_snapshot text not null,
 quantity integer not null check(quantity between 1 and 100),
 unit_price_iqd bigint not null check(unit_price_iqd between 0 and 1000000000),
 price_mode text not null check(price_mode in ('normal','tourism')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id)
);
create index if not exists gs_counter_request_items_req_idx on public.gs_counter_order_request_items(request_id);
alter table public.gs_counter_order_request_items enable row level security;
revoke all on public.gs_counter_order_request_items from public,anon,authenticated;

create or replace function public.gs_add_counter_request_menu_item(
 p_request_id bigint,p_product_id bigint,p_quantity integer,p_price_mode text default 'normal')
returns bigint language plpgsql security definer set search_path='' as $$
declare v_request public.gs_counter_order_requests%rowtype;
 v_product public.gs_menu_products%rowtype; v_id bigint; v_price bigint;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Not authorized to edit counter requests'; end if;
 if p_quantity not between 1 and 100 or p_price_mode not in ('normal','tourism') then
  raise exception 'Invalid quantity or price mode'; end if;
 select * into v_request from public.gs_counter_order_requests
  where id=p_request_id for update;
 if not found then raise exception 'Request not found'; end if;
 if v_request.status <> 'pending' then raise exception 'Request is not editable'; end if;
 select * into v_product from public.gs_menu_products where id=p_product_id;
 if not found or v_product.is_active is distinct from true then
  raise exception 'Menu product unavailable'; end if;
 v_price := case when p_price_mode='tourism' then v_product.tourism_price_iqd
   else v_product.normal_price_iqd end;
 if v_price is null or v_price < 0 then raise exception 'Product has invalid price'; end if;
 insert into public.gs_counter_order_request_items(request_id,product_id,
   product_name_snapshot,quantity,unit_price_iqd,price_mode,created_by)
 values(p_request_id,p_product_id,v_product.name,p_quantity,v_price,p_price_mode,auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_add_counter_request_menu_item(bigint,bigint,integer,text) from public,anon;
grant execute on function public.gs_add_counter_request_menu_item(bigint,bigint,integer,text) to authenticated;

create or replace function public.gs_counter_request_item_summary(p_request_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_data jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.gs_counter_order_requests where id=p_request_id) then
  raise exception 'Request not found'; end if;
 select jsonb_build_object('request_id',p_request_id,
  'priced_items',coalesce(jsonb_agg(jsonb_build_object('id',id,'product',product_name_snapshot,
   'quantity',quantity,'unit_price_iqd',unit_price_iqd,
   'line_total_iqd',quantity*unit_price_iqd,'mode',price_mode)
   order by id) filter(where id is not null),'[]'::jsonb),
  'draft_total_iqd',coalesce(sum(quantity*unit_price_iqd),0),
  'payment_status','NOT_POSTED','kitchen_status','NOT_SUBMITTED')
 into v_data from public.gs_counter_order_request_items where request_id=p_request_id;
 return v_data;
end; $$;
revoke all on function public.gs_counter_request_item_summary(bigint) from public,anon;
grant execute on function public.gs_counter_request_item_summary(bigint) to authenticated;
