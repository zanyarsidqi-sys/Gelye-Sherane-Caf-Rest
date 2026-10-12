-- Upgrade 1143: lock item rows while validating served handover.
-- Review and apply after the gs_ base kitchen migrations. No direct table
-- UPDATE permission is granted to clients.
create or replace function public.gs_update_kitchen_status(
  p_order_id bigint, p_next_status text
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_current text;
  v_item_count bigint;
  v_invalid_count bigint;
begin
  if auth.uid() is null or not public.gs_can_access('kitchen', 'can_edit') then
    raise exception 'Not authorized to update kitchen orders';
  end if;
  if p_order_id is null or p_order_id <= 0 or p_next_status is null then
    raise exception 'Valid order and status are required';
  end if;
  select status into v_current from public.gs_orders
    where id = p_order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if not ((v_current = 'new' and p_next_status = 'preparing')
       or (v_current = 'preparing' and p_next_status = 'ready')
       or (v_current = 'ready' and p_next_status = 'served')) then
    raise exception 'Invalid status transition from % to %', v_current, p_next_status;
  end if;
  if p_next_status = 'served' then
    -- Serialize concurrent edits to the order items while validating.
    -- The FK to gs_orders makes concurrent child inserts take a parent
    -- KEY SHARE lock; the parent FOR UPDATE above conflicts with that lock.
    -- Lock every current child row, not only the parent. An UPDATE to an
    -- item's quantity or price does not need a parent FK KEY SHARE lock.
    -- Locking rows prevents concurrent modifications between validation and
    -- the final served transition. The parent lock blocks concurrent inserts.
    select count(*), count(*) filter (where
        product_id is null or quantity is null or quantity <= 0
        or unit_price_iqd is null or unit_price_iqd < 0
        or line_total_iqd is null
        or line_total_iqd::numeric <> quantity::numeric * unit_price_iqd::numeric)
      into v_item_count, v_invalid_count
      from (
        select product_id, quantity, unit_price_iqd, line_total_iqd
          from public.gs_order_items
          where order_id = p_order_id
          for update
      ) locked_items;
    if v_item_count = 0 then
      raise exception 'Cannot serve an order without items';
    end if;
    if v_invalid_count > 0 then
      raise exception 'Cannot serve an order with invalid items';
    end if;
  end if;
  update public.gs_orders set status = p_next_status where id = p_order_id;
end;
$$;
revoke all on function public.gs_update_kitchen_status(bigint,text) from public, anon;
grant execute on function public.gs_update_kitchen_status(bigint,text) to authenticated;
