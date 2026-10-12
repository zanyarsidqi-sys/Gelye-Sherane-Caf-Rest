-- Upgrade 1144: prevent changing item records after a kitchen order is served.
-- Run after migration 1143. Server-side protection applies to all write paths.
-- This does not replace staging transaction/concurrency testing.
create or replace function public.gs_guard_served_order_items()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_status text;
  v_order_id bigint;
begin
  -- An item may not be moved between orders; that would invalidate
  -- a previously completed handover or stock-consumption ledger.
  if tg_op = 'UPDATE' and new.order_id is distinct from old.order_id then
    raise exception 'Moving order items between orders is not permitted';
  end if;
  v_order_id := case when tg_op = 'DELETE' then old.order_id else new.order_id end;
  -- Take the same parent lock used by the kitchen status RPC. This ensures
  -- the item write and served transition cannot both commit out of order.
  select status into v_status from public.gs_orders
    where id = v_order_id for update;
  if not found then
    raise exception 'Order not found for item change';
  end if;
  if v_status = 'served' then
    raise exception 'Served order items cannot be modified';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.gs_guard_served_order_items() from public, anon, authenticated;
drop trigger if exists gs_guard_served_order_items on public.gs_order_items;
create trigger gs_guard_served_order_items
before insert or update or delete on public.gs_order_items
for each row execute function public.gs_guard_served_order_items();
