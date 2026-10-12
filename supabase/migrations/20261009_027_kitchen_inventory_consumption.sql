-- Phase 3 / Step 3: consume explicitly tracked finished products when served.
-- Apply after 026. Recipe ingredients are NOT inferred: a menu product must be
-- explicitly enrolled in gs_inventory_stock to participate in deduction.
-- Run acceptance tests in staging before enabling in production.
create table if not exists public.gs_kitchen_stock_consumption (
  order_id bigint not null references public.gs_orders(id),
  product_id bigint not null references public.gs_menu_products(id),
  quantity bigint not null check (quantity > 0),
  created_at timestamptz not null default now(),
  primary key (order_id, product_id)
);
alter table public.gs_kitchen_stock_consumption enable row level security;
revoke all on public.gs_kitchen_stock_consumption from public, anon, authenticated;

create or replace function public.gs_consume_stock_when_served()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r record; v_remaining bigint;
begin
  if new.status <> 'served' or old.status = 'served' then return new; end if;
  -- Stable product order reduces deadlock risk for simultaneous kitchen handovers.
  for r in
    select i.product_id, sum(i.quantity)::bigint as qty
    from public.gs_order_items i
    join public.gs_inventory_stock s on s.product_id = i.product_id
    where i.order_id = new.id
    group by i.product_id order by i.product_id
  loop
    -- Both stock decrement and consumption record are in the same transaction.
    update public.gs_inventory_stock
       set quantity = quantity - r.qty, updated_at = now()
     where product_id = r.product_id and quantity >= r.qty
     returning quantity into v_remaining;
    if not found then
      raise exception 'Insufficient tracked stock for product %; order remains unserved', r.product_id;
    end if;
    insert into public.gs_kitchen_stock_consumption(order_id,product_id,quantity)
      values(new.id,r.product_id,r.qty);
    insert into public.gs_inventory_movements(product_id,delta,reason,employee_id)
      values(r.product_id,-r.qty,'Kitchen served order #' || new.id, auth.uid());
  end loop;
  return new;
end; $$;
revoke all on function public.gs_consume_stock_when_served() from public;
drop trigger if exists gs_kitchen_stock_on_served on public.gs_orders;
create trigger gs_kitchen_stock_on_served
before update of status on public.gs_orders
for each row execute function public.gs_consume_stock_when_served();
