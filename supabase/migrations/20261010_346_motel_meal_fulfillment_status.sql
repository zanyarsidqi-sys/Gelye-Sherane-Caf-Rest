-- Upgrade 346: auditable staff fulfillment transitions for scheduled motel meals.
-- This does not dispatch a kitchen ticket or charge a room.
create or replace function public.gs_staff_progress_motel_scheduled_meal(p_meal_id uuid, p_next_status text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_previous text; v_expected text;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then
   raise exception 'Motel Orders edit permission required';
 end if;
 select status into v_previous from public.gs_motel_scheduled_meals where id=p_meal_id for update;
 if v_previous is null then raise exception 'Meal request not found'; end if;
 v_expected := case v_previous
   when 'confirmed' then 'scheduled'
   when 'scheduled' then 'preparing'
   when 'preparing' then 'ready'
   when 'ready' then 'on_way'
   when 'on_way' then 'delivered'
   else null end;
 if v_expected is null or p_next_status is distinct from v_expected then
   raise exception 'Invalid meal status transition';
 end if;
 update public.gs_motel_scheduled_meals set status=p_next_status,updated_at=now() where id=p_meal_id;
 insert into public.gs_motel_scheduled_meal_audit(meal_id,actor_id,old_status,new_status,reason)
 values(p_meal_id,auth.uid(),v_previous,p_next_status,'Staff fulfillment update');
 return p_next_status;
end; $$;
revoke all on function public.gs_staff_progress_motel_scheduled_meal(uuid,text) from public,anon;
grant execute on function public.gs_staff_progress_motel_scheduled_meal(uuid,text) to authenticated;
