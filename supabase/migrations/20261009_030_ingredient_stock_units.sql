-- Explicit inventory units. Existing stock quantities are NOT converted automatically.
-- Administrators must verify physical units before setting a unit other than 'piece'.
create table if not exists public.gs_inventory_units (
 product_id bigint primary key references public.gs_menu_products(id) on delete cascade,
 stock_unit text not null check (stock_unit in ('piece','gram','milliliter')),
 updated_by uuid not null,
 updated_at timestamptz not null default now()
);
alter table public.gs_inventory_units enable row level security;
revoke all on public.gs_inventory_units from public,anon,authenticated;

create or replace function public.gs_recipe_stock_units()
returns table(product_id bigint, stock_unit text, is_configured boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_view') then raise exception 'Access denied'; end if;
 return query select p.id, coalesce(u.stock_unit,'unconfigured')::text,(u.product_id is not null)
 from public.gs_menu_products p left join public.gs_inventory_units u on u.product_id=p.id
 where p.is_active=true order by p.name;
end; $$;

create or replace function public.gs_set_inventory_unit(p_product_id bigint,p_unit text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_edit') then raise exception 'Access denied'; end if;
 if p_unit not in ('piece','gram','milliliter') or p_unit is null then raise exception 'Unsupported stock unit'; end if;
 if not exists(select 1 from public.gs_menu_products where id=p_product_id and is_active=true) then raise exception 'Unknown product'; end if;
 -- Never relabel an existing quantity or recipe without manual migration/conversion.
 if exists(select 1 from public.gs_inventory_units where product_id=p_product_id and stock_unit<>p_unit)
    or exists(select 1 from public.gs_inventory_stock where product_id=p_product_id and quantity<>0)
       and not exists(select 1 from public.gs_inventory_units where product_id=p_product_id and stock_unit=p_unit)
    or exists(select 1 from public.gs_product_recipes where ingredient_product_id=p_product_id)
       and not exists(select 1 from public.gs_inventory_units where product_id=p_product_id and stock_unit=p_unit)
 then raise exception 'Stock or recipes exist: unit conversion requires a manual audited migration'; end if;
 insert into public.gs_inventory_units(product_id,stock_unit,updated_by) values(p_product_id,p_unit,auth.uid())
 on conflict(product_id) do update set updated_at=now(),updated_by=excluded.updated_by;
end; $$;

-- Require explicitly configured units for all new recipe components.
create or replace function public.gs_recipe_unit_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if not exists(select 1 from public.gs_inventory_units where product_id=new.ingredient_product_id)
 then raise exception 'Configure ingredient stock unit before adding recipe'; end if;
 return new;
end; $$;
drop trigger if exists gs_recipe_unit_guard_trigger on public.gs_product_recipes;
create trigger gs_recipe_unit_guard_trigger before insert or update on public.gs_product_recipes
for each row execute function public.gs_recipe_unit_guard();
revoke all on function public.gs_recipe_stock_units(),public.gs_set_inventory_unit(bigint,text) from public;
grant execute on function public.gs_recipe_stock_units(),public.gs_set_inventory_unit(bigint,text) to authenticated;
