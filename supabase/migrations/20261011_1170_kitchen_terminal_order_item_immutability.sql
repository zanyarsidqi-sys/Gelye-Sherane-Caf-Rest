-- Upgrade 1170: prevent modifications to cancelled as well as served orders.
create or replace function public.gs_guard_served_order_items()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_status text; v_order_id bigint;
begin
  if tg_op = 'UPDATE' and new.order_id is distinct from old.order_id then
    raise exception 'Moving order items between orders is not permitted';
  end if;
  v_order_id := case when tg_op = 'DELETE' then old.order_id else new.order_id end;
  select status into v_status from public.gs_orders where id = v_order_id for update;
  if not found then raise exception 'Order not found for item change'; end if;
  if v_status in ('served', 'cancelled') then
    raise exception 'Completed or cancelled order items cannot be modified';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.gs_guard_served_order_items() from public, anon, authenticated;
-- Existing trigger installed by 1144 continues to call this replaced function.
