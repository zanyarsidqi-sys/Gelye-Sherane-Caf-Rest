-- Step 3: explicit recipe components. Quantities use integer stock units;
-- configure products consistently (e.g. grams as units) before enabling.
-- Requires 026 and 027. Test in staging before production deployment.
create table if not exists public.gs_product_recipes (
 menu_product_id bigint not null references public.gs_menu_products(id) on delete cascade,
 ingredient_product_id bigint not null references public.gs_menu_products(id) on delete restrict,
 quantity_per_item bigint not null check (quantity_per_item > 0 and quantity_per_item <= 1000000),
 updated_by uuid not null,
 updated_at timestamptz not null default now(),
 primary key(menu_product_id,ingredient_product_id),
 check (menu_product_id <> ingredient_product_id)
);
alter table public.gs_product_recipes enable row level security;
revoke all on public.gs_product_recipes from public,anon,authenticated;

create or replace function public.gs_recipe_components(p_menu_product_id bigint)
returns table(ingredient_product_id bigint,ingredient_name text,quantity_per_item bigint)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_view') then raise exception 'Recipe access denied'; end if;
 return query select r.ingredient_product_id,p.name::text,r.quantity_per_item
 from public.gs_product_recipes r join public.gs_menu_products p on p.id=r.ingredient_product_id
 where r.menu_product_id=p_menu_product_id order by p.name;
end; $$;

create or replace function public.gs_recipe_set_component(p_menu_product_id bigint,p_ingredient_product_id bigint,p_quantity bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_edit') then raise exception 'Recipe editing denied'; end if;
 if p_menu_product_id is null or p_ingredient_product_id is null or p_menu_product_id=p_ingredient_product_id
    or p_quantity is null or p_quantity < 0 or p_quantity > 1000000 then raise exception 'Invalid recipe component'; end if;
 if not exists(select 1 from public.gs_menu_products where id=p_menu_product_id and is_active=true)
    or not exists(select 1 from public.gs_menu_products where id=p_ingredient_product_id and is_active=true)
 then raise exception 'Both products must be active'; end if;
 -- A zero quantity removes the ingredient; no negative quantities allowed.
 if p_quantity=0 then
  delete from public.gs_product_recipes where menu_product_id=p_menu_product_id and ingredient_product_id=p_ingredient_product_id;
 else
  insert into public.gs_product_recipes(menu_product_id,ingredient_product_id,quantity_per_item,updated_by)
  values(p_menu_product_id,p_ingredient_product_id,p_quantity,auth.uid())
  on conflict(menu_product_id,ingredient_product_id) do update
   set quantity_per_item=excluded.quantity_per_item,updated_by=excluded.updated_by,updated_at=now();
 end if;
end; $$;
revoke all on function public.gs_recipe_components(bigint),public.gs_recipe_set_component(bigint,bigint,bigint) from public;
grant execute on function public.gs_recipe_components(bigint),public.gs_recipe_set_component(bigint,bigint,bigint) to authenticated;

-- Replace 027 trigger. For menu items with a recipe, consume ingredients only;
-- otherwise retain 027's explicitly tracked finished-product deduction.
create or replace function public.gs_consume_stock_when_served()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r record; v_remaining bigint;
begin
 if new.status <> 'served' or old.status = 'served' then return new; end if;
 -- Recipe ingredients must be enrolled in stock; never silently skip them.
 if exists (select 1 from public.gs_order_items i
   join public.gs_product_recipes c on c.menu_product_id=i.product_id
   left join public.gs_inventory_stock s on s.product_id=c.ingredient_product_id
   where i.order_id=new.id and s.product_id is null) then
   raise exception 'Recipe ingredient has no inventory stock record';
 end if;
 for r in
  with required as (
   select coalesce(c.ingredient_product_id,i.product_id) as stock_product_id,
          (i.quantity::bigint * coalesce(c.quantity_per_item,1)::bigint) as qty
   from public.gs_order_items i
   left join public.gs_product_recipes c on c.menu_product_id=i.product_id
   where i.order_id=new.id
  )
  select q.stock_product_id as product_id,sum(q.qty)::bigint as qty
  from required q
  join public.gs_inventory_stock s on s.product_id=q.stock_product_id
  group by q.stock_product_id order by q.stock_product_id
 loop
  update public.gs_inventory_stock
  set quantity=quantity-r.qty,updated_at=now()
  where product_id=r.product_id and quantity>=r.qty returning quantity into v_remaining;
  if not found then raise exception 'Insufficient stock for product %; order remains unserved',r.product_id; end if;
  insert into public.gs_kitchen_stock_consumption(order_id,product_id,quantity)
  values(new.id,r.product_id,r.qty)
  on conflict(order_id,product_id) do nothing;
  if not found then raise exception 'Order stock consumption already recorded for product %',r.product_id; end if;
  insert into public.gs_inventory_movements(product_id,delta,reason,employee_id)
  values(r.product_id,-r.qty,'Kitchen served order #' || new.id,coalesce(auth.uid(),new.created_by));
 end loop;
 return new;
end; $$;
