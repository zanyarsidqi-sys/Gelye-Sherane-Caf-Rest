-- OPTIONAL, REVIEW BEFORE APPLYING. Requires existing employee_profiles and
-- employee_section_permissions tables as used by EmployeePermissionService.
-- Dedicated gs_ names avoid overwriting existing application tables.
create table if not exists public.gs_menu_products (
 id bigint generated always as identity primary key,
 barcode text not null unique check (length(trim(barcode)) > 0),
 name text not null check (length(trim(name)) > 0),
 normal_price_iqd bigint not null check (normal_price_iqd >= 0),
 tourism_price_iqd bigint not null check (tourism_price_iqd >= 0),
 is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.gs_orders (
 id bigint generated always as identity primary key,
 created_by uuid not null references auth.users(id),
 destination text not null check (length(trim(destination)) > 0),
 is_motel boolean not null,
 tourism_mode boolean not null,
 status text not null default 'new' check (status in ('new','preparing','ready','served','cancelled')),
 created_at timestamptz not null default now(),
 constraint gs_motel_tourism check (not is_motel or tourism_mode)
);
create table if not exists public.gs_order_items (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 product_id bigint not null references public.gs_menu_products(id),
 quantity integer not null check (quantity between 1 and 999),
 unit_price_iqd bigint not null check (unit_price_iqd >= 0),
 line_total_iqd bigint generated always as (quantity * unit_price_iqd) stored
);
create index if not exists gs_orders_created_at_idx on public.gs_orders(created_at desc);
create index if not exists gs_order_items_order_id_idx on public.gs_order_items(order_id);
alter table public.gs_menu_products enable row level security;
alter table public.gs_orders enable row level security;
alter table public.gs_order_items enable row level security;
-- Read access is limited to active employees with the relevant permission.
create or replace function public.gs_can_access(p_section text, p_action text default 'can_view')
returns boolean language sql stable security definer set search_path = '' as $$
 select exists (
  select 1 from public.employee_profiles ep
  join public.employee_section_permissions perm on perm.user_id = ep.user_id
  where ep.user_id = (select auth.uid()) and ep.is_active = true
    and perm.section_key = p_section
    and case p_action when 'can_view' then perm.can_view
      when 'can_create' then perm.can_create
      when 'can_edit' then perm.can_edit
      else false end = true
 );
$$;
revoke all on function public.gs_can_access(text,text) from public;
grant execute on function public.gs_can_access(text,text) to authenticated;
create policy gs_products_read on public.gs_menu_products for select to authenticated
 using (public.gs_can_access('menu') or public.gs_can_access('table_orders') or public.gs_can_access('motel_orders'));
create policy gs_orders_read on public.gs_orders for select to authenticated
 using (public.gs_can_access(case when is_motel then 'motel_orders' else 'table_orders' end)
        or public.gs_can_access('kitchen'));
create policy gs_order_items_read on public.gs_order_items for select to authenticated
 using (exists (select 1 from public.gs_orders o where o.id = order_id));
-- NO direct insert/update/delete policies: all order creation goes through RPC.
-- Pricing is looked up server-side; client-supplied prices are never trusted.
create or replace function public.gs_create_order(
 p_destination text, p_is_motel boolean, p_tourism_mode boolean,
 p_product_id bigint, p_quantity integer)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_section text;
 v_price bigint; v_order_id bigint; v_tourism boolean;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 v_section := case when p_is_motel then 'motel_orders' else 'table_orders' end;
 if not public.gs_can_access(v_section, 'can_create') then
  raise exception 'Not authorized to create orders';
 end if;
 if p_destination is null or length(trim(p_destination)) = 0 or length(p_destination) > 120 then
  raise exception 'Invalid destination';
 end if;
 if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
  raise exception 'Invalid quantity';
 end if;
 v_tourism := p_is_motel or coalesce(p_tourism_mode,false);
 select case when v_tourism then tourism_price_iqd else normal_price_iqd end
 into v_price from public.gs_menu_products
 where id = p_product_id and is_active = true;
 if not found then raise exception 'Product unavailable'; end if;
 insert into public.gs_orders(created_by,destination,is_motel,tourism_mode)
 values(v_uid,trim(p_destination),p_is_motel,v_tourism) returning id into v_order_id;
 insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd)
 values(v_order_id,p_product_id,p_quantity,v_price);
 return v_order_id;
end;
$$;
revoke all on function public.gs_create_order(text,boolean,boolean,bigint,integer) from public;
grant execute on function public.gs_create_order(text,boolean,boolean,bigint,integer) to authenticated;
-- Products are provisioned by an authorized administrative workflow (not included here).
