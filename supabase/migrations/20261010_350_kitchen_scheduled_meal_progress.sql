-- Kitchen-specific preparation actions for approved scheduled motel meals.
-- Delivery and charging remain separate workflows.
create or replace function public.gs_kitchen_progress_motel_scheduled_meal(
  p_meal_id uuid, p_next_status text
) returns text
language plpgsql security definer set search_path = '' as $$
declare v_previous text;
begin
  if auth.uid() is null or not public.gs_can_access('kitchen', 'can_edit') then
    raise exception 'Kitchen edit permission required';
  end if;
  if p_next_status not in ('preparing','ready') then
    raise exception 'Kitchen may only set Preparing or Ready';
  end if;
  select status into v_previous
  from public.gs_motel_scheduled_meals where id = p_meal_id for update;
  if not found then raise exception 'Scheduled meal not found'; end if;
  if not ((v_previous in ('confirmed','scheduled') and p_next_status='preparing')
      or (v_previous='preparing' and p_next_status='ready')) then
    raise exception 'Invalid kitchen preparation transition';
  end if;
  update public.gs_motel_scheduled_meals
    set status=p_next_status, updated_at=now() where id=p_meal_id;
  insert into public.gs_motel_scheduled_meal_audit
    (meal_id,actor_id,old_status,new_status,reason)
    values (p_meal_id,auth.uid(),v_previous,p_next_status,'Kitchen preparation update');
  return p_next_status;
end; $$;
revoke all on function public.gs_kitchen_progress_motel_scheduled_meal(uuid,text) from public,anon;
grant execute on function public.gs_kitchen_progress_motel_scheduled_meal(uuid,text) to authenticated;
