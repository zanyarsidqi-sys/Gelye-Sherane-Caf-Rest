-- Upgrade 357: assign delivery to current authorized employee, then dispatch and complete.
-- Assignment is explicit; only assigned employee may advance delivery.
alter table public.gs_motel_guest_food_requests
 add column if not exists delivery_employee_id uuid references auth.users(id),
 add column if not exists delivery_assigned_at timestamptz,
 add column if not exists delivered_at timestamptz;

create or replace function public.gs_staff_advance_motel_food_delivery(p_request_id uuid,p_action text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_order public.gs_motel_guest_food_requests%rowtype; v_new text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false) then
  raise exception 'Not authorized'; end if;
 if p_action not in ('assign_to_me','on_way','delivered') then raise exception 'Invalid delivery action'; end if;
 select * into v_order from public.gs_motel_guest_food_requests where id=p_request_id for update;
 if not found then raise exception 'Food request not found'; end if;
 if p_action='assign_to_me' then
  if v_order.status <> 'ready' or v_order.delivery_employee_id is not null then
   raise exception 'Only unassigned ready orders may be claimed'; end if;
  update public.gs_motel_guest_food_requests
  set delivery_employee_id=auth.uid(),delivery_assigned_at=now() where id=p_request_id;
  insert into public.gs_motel_food_request_audit(request_id,actor_id,old_status,new_status,reason)
  values(p_request_id,auth.uid(),v_order.status,v_order.status,'Delivery assigned to employee');
  return 'assigned';
 end if;
 if v_order.delivery_employee_id is distinct from auth.uid() then
  raise exception 'Only the assigned delivery employee can advance this order'; end if;
 if p_action='on_way' and v_order.status='ready' then v_new:='on_way';
 elsif p_action='delivered' and v_order.status='on_way' then v_new:='delivered';
 else raise exception 'Invalid delivery status transition'; end if;
 update public.gs_motel_guest_food_requests
 set status=v_new,delivered_at=case when v_new='delivered' then now() else delivered_at end
 where id=p_request_id;
 insert into public.gs_motel_food_request_audit(request_id,actor_id,old_status,new_status,reason)
 values(p_request_id,auth.uid(),v_order.status,v_new,'Delivery: '||p_action);
 return v_new;
end; $$;
revoke all on function public.gs_staff_advance_motel_food_delivery(uuid,text) from public;
grant execute on function public.gs_staff_advance_motel_food_delivery(uuid,text) to authenticated;

-- Extend employee listing with delivery assignment, keeping existing output columns stable.
drop function if exists public.gs_staff_list_motel_food_requests();
create function public.gs_staff_list_motel_food_requests()
returns table(id uuid,room_label text,room_name text,status text,total_iqd bigint,
 created_at timestamptz,items jsonb,delivery_employee_id uuid,delivery_assigned_at timestamptz,delivered_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Not authorized'; end if;
 return query select o.id,r.room_label,r.room_name,o.status,o.total_iqd,o.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,'price_iqd',i.unit_price_iqd)
 order by i.product_name) from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb),
 o.delivery_employee_id,o.delivery_assigned_at,o.delivered_at
 from public.gs_motel_guest_food_requests o join public.gs_motel_room_qr r on r.id=o.room_id
 order by case when o.status='pending' then 0 when o.status='ready' then 1 when o.status='on_way' then 2 else 3 end,
 o.created_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_food_requests() from public;
grant execute on function public.gs_staff_list_motel_food_requests() to authenticated;
