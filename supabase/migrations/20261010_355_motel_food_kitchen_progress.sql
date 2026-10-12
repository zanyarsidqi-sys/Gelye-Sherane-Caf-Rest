-- Upgrade 355: kitchen progress on accepted motel food requests. No billing or inventory movement.
alter table public.gs_motel_guest_food_requests drop constraint if exists gs_motel_guest_food_requests_status_check;
alter table public.gs_motel_guest_food_requests add constraint gs_motel_guest_food_requests_status_check
 check (status in ('pending','accepted','preparing','ready','on_way','delivered','rejected','cancelled'));
create or replace function public.gs_kitchen_advance_motel_food(p_request_id uuid,p_action text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_old text; v_new text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('kitchen','can_edit'),false) then
  raise exception 'Not authorized'; end if;
 if p_action not in ('start_preparing','mark_ready') then raise exception 'Invalid kitchen action'; end if;
 select status into v_old from public.gs_motel_guest_food_requests where id=p_request_id for update;
 if not found then raise exception 'Order not found'; end if;
 if p_action='start_preparing' and v_old='accepted' then v_new:='preparing';
 elsif p_action='mark_ready' and v_old='preparing' then v_new:='ready';
 else raise exception 'Invalid kitchen status transition'; end if;
 update public.gs_motel_guest_food_requests set status=v_new where id=p_request_id;
 insert into public.gs_motel_food_request_audit(request_id,actor_id,old_status,new_status,reason)
 values(p_request_id,auth.uid(),v_old,v_new,'Kitchen: '||p_action);
 return v_new;
end; $$;
create or replace function public.gs_kitchen_list_accepted_motel_food()
returns table(id uuid, room_label text, room_name text, status text, total_iqd bigint, created_at timestamptz, items jsonb)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('kitchen','can_view'),false) then
  raise exception 'Not authorized'; end if;
 return query
 select o.id,r.room_label,r.room_name,o.status,o.total_iqd,o.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,'price_iqd',i.unit_price_iqd)
 order by i.product_name) from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb)
 from public.gs_motel_guest_food_requests o join public.gs_motel_room_qr r on r.id=o.room_id
 where o.status in ('accepted','preparing','ready')
 order by case o.status when 'accepted' then 0 when 'preparing' then 1 else 2 end,o.created_at asc limit 200;
end; $$;
revoke all on function public.gs_kitchen_advance_motel_food(uuid,text) from public;
grant execute on function public.gs_kitchen_advance_motel_food(uuid,text) to authenticated;
revoke all on function public.gs_kitchen_list_accepted_motel_food() from public;
grant execute on function public.gs_kitchen_list_accepted_motel_food() to authenticated;
