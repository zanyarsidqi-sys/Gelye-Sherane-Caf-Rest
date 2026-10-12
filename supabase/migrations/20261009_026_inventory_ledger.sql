-- Apply after menu and employee permission migrations. Review permission mapping before deployment.
create table if not exists public.gs_inventory_stock (
 product_id bigint primary key references public.gs_menu_products(id) on delete restrict,
 quantity bigint not null default 0 check (quantity >= 0),
 minimum_quantity bigint not null default 5 check (minimum_quantity >= 0),
 updated_at timestamptz not null default now()
);
create table if not exists public.gs_inventory_movements (
 id bigint generated always as identity primary key,
 product_id bigint not null references public.gs_menu_products(id),
 delta bigint not null check (delta <> 0),
 reason text not null check (length(trim(reason)) between 3 and 300),
 employee_id uuid not null,
 created_at timestamptz not null default now()
);
alter table public.gs_inventory_stock enable row level security;
alter table public.gs_inventory_movements enable row level security;
revoke all on public.gs_inventory_stock, public.gs_inventory_movements from anon, authenticated;
create or replace function public.gs_inventory_overview()
returns table(product_id bigint, name text, barcode text, quantity bigint, minimum_quantity bigint, is_low boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_view') then
  raise exception 'Inventory access denied';
 end if;
 return query select p.id,p.name::text,p.barcode::text,coalesce(s.quantity,0)::bigint,
 coalesce(s.minimum_quantity,5)::bigint,
 coalesce(s.quantity,0) <= coalesce(s.minimum_quantity,5)
 from public.gs_menu_products p left join public.gs_inventory_stock s on s.product_id=p.id
 where p.is_active=true order by p.name;
end; $$;
create or replace function public.gs_inventory_adjust(p_product_id bigint,p_delta bigint,p_reason text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_quantity bigint;
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_edit') then
  raise exception 'Inventory modification denied';
 end if;
 if p_delta is null or p_delta=0 or abs(p_delta)>1000000 or length(trim(coalesce(p_reason,''))) not between 3 and 300 then
  raise exception 'Invalid movement';
 end if;
 if not exists(select 1 from public.gs_menu_products where id=p_product_id and is_active=true) then
  raise exception 'Unknown or inactive product';
 end if;
 insert into public.gs_inventory_stock(product_id) values(p_product_id) on conflict do nothing;
 update public.gs_inventory_stock set quantity=quantity+p_delta,updated_at=now()
 where product_id=p_product_id and quantity+p_delta>=0 returning quantity into v_quantity;
 if not found then raise exception 'Insufficient stock'; end if;
 insert into public.gs_inventory_movements(product_id,delta,reason,employee_id)
 values(p_product_id,p_delta,trim(p_reason),auth.uid());
 return v_quantity;
end; $$;
create or replace function public.gs_inventory_set_minimum(p_product_id bigint,p_minimum bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_edit') then raise exception 'Inventory modification denied'; end if;
 if p_minimum is null or p_minimum<0 or p_minimum>1000000 then raise exception 'Invalid minimum'; end if;
 if not exists(select 1 from public.gs_menu_products where id=p_product_id) then raise exception 'Unknown product'; end if;
 insert into public.gs_inventory_stock(product_id,minimum_quantity) values(p_product_id,p_minimum)
 on conflict(product_id) do update set minimum_quantity=excluded.minimum_quantity,updated_at=now();
end; $$;
revoke all on function public.gs_inventory_overview(), public.gs_inventory_adjust(bigint,bigint,text), public.gs_inventory_set_minimum(bigint,bigint) from public;
grant execute on function public.gs_inventory_overview(), public.gs_inventory_adjust(bigint,bigint,text), public.gs_inventory_set_minimum(bigint,bigint) to authenticated;
