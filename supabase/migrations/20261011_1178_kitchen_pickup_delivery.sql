-- Upgrade 1178: separate employee-attributed pickup and delivery milestones.
alter table public.gs_orders
 add column if not exists kitchen_picked_up_at timestamptz,
 add column if not exists kitchen_picked_up_by uuid references auth.users(id),
 add column if not exists kitchen_delivered_at timestamptz,
 add column if not exists kitchen_delivered_by uuid references auth.users(id);

create or replace function public.gs_pickup_kitchen_order(p_order_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_status text; v_pickup timestamptz;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
   raise exception 'Not authorized for kitchen pickup';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Valid order ID required'; end if;
 select status,kitchen_picked_up_at into v_status,v_pickup
 from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 if v_status <> 'ready' or v_pickup is not null then
   raise exception 'Only ready, uncollected orders can be picked up';
 end if;
 update public.gs_orders
 set kitchen_picked_up_at=transaction_timestamp(), kitchen_picked_up_by=auth.uid()
 where id=p_order_id;
end;
$$;
revoke all on function public.gs_pickup_kitchen_order(bigint) from public,anon;
grant execute on function public.gs_pickup_kitchen_order(bigint) to authenticated;

-- Existing served transition must now have a recorded pickup.
create or replace function public.gs_require_kitchen_delivery_pickup()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.status = 'ready' and new.status = 'served' then
   if old.kitchen_picked_up_at is null or old.kitchen_picked_up_by is null then
     raise exception 'Pickup must be recorded before delivery';
   end if;
   new.kitchen_delivered_at := transaction_timestamp();
   new.kitchen_delivered_by := auth.uid();
   if new.kitchen_delivered_by is null then
     raise exception 'Authenticated delivery employee required';
   end if;
 end if;
 return new;
end;
$$;
drop trigger if exists gs_require_kitchen_delivery_pickup on public.gs_orders;
create trigger gs_require_kitchen_delivery_pickup
before update of status on public.gs_orders for each row
execute function public.gs_require_kitchen_delivery_pickup();
revoke all on function public.gs_require_kitchen_delivery_pickup() from public,anon,authenticated;

-- Read via controlled RPC, not direct access to employee metadata.
create or replace function public.gs_get_kitchen_delivery_history(p_order_id bigint)
returns table(picked_up_at timestamptz,picked_up_by uuid,delivered_at timestamptz,delivered_by uuid)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Not authorized to view kitchen delivery history';
 end if;
 return query select o.kitchen_picked_up_at,o.kitchen_picked_up_by,
 o.kitchen_delivered_at,o.kitchen_delivered_by
 from public.gs_orders o where o.id=p_order_id;
end;
$$;
revoke all on function public.gs_get_kitchen_delivery_history(bigint) from public,anon;
grant execute on function public.gs_get_kitchen_delivery_history(bigint) to authenticated;
