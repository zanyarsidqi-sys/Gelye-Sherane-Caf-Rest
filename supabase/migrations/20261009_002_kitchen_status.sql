-- Phase 3 Batch 10. OPTIONAL: Apply only after 001 migration is reviewed and applied.
-- Controlled kitchen status changes; no direct UPDATE policy is added.
create or replace function public.gs_update_kitchen_status(p_order_id bigint, p_next_status text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_current text;
begin
  if auth.uid() is null or not public.gs_can_access('kitchen', 'can_edit') then
    raise exception 'Not authorized to update kitchen orders';
  end if;
  if p_order_id is null or p_next_status is null then
    raise exception 'Order and status are required';
  end if;
  select status into v_current from public.gs_orders where id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if not ((v_current = 'new' and p_next_status = 'preparing')
       or (v_current = 'preparing' and p_next_status = 'ready')
       or (v_current = 'ready' and p_next_status = 'served')) then
    raise exception 'Invalid status transition from % to %', v_current, p_next_status;
  end if;
  update public.gs_orders set status = p_next_status where id = p_order_id;
end;
$$;
revoke all on function public.gs_update_kitchen_status(bigint,text) from public;
grant execute on function public.gs_update_kitchen_status(bigint,text) to authenticated;
