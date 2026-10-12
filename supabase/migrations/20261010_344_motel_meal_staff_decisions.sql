-- Staff decisions on guest and employee scheduled meal requests.
-- Confirmation is not a payment, kitchen ticket, or authorization to charge a room.
create table if not exists public.gs_motel_scheduled_meal_audit (
 id bigint generated always as identity primary key,
 meal_id uuid not null references public.gs_motel_scheduled_meals(id),
 actor_id uuid not null references auth.users(id),
 old_status text not null,
 new_status text not null,
 reason text,
 changed_at timestamptz not null default now()
);
alter table public.gs_motel_scheduled_meal_audit enable row level security;
revoke all on public.gs_motel_scheduled_meal_audit from public, anon, authenticated;
create or replace function public.gs_staff_decide_motel_scheduled_meal(
 p_meal_id uuid, p_decision text, p_reason text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare v_old text; v_new text;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then
  raise exception 'Motel Orders edit permission required';
 end if;
 if p_decision not in ('confirm','reject') then raise exception 'Invalid decision'; end if;
 if p_decision='reject' and length(trim(coalesce(p_reason,'')))<3 then
  raise exception 'A rejection reason is required';
 end if;
 if length(coalesce(p_reason,''))>500 then raise exception 'Reason too long'; end if;
 select status into v_old from public.gs_motel_scheduled_meals
 where id=p_meal_id for update;
 if v_old is null then raise exception 'Meal request not found'; end if;
 if v_old <> 'requested' then raise exception 'Only requested meals can be decided'; end if;
 v_new := case when p_decision='confirm' then 'confirmed' else 'rejected' end;
 update public.gs_motel_scheduled_meals set status=v_new,updated_at=now() where id=p_meal_id;
 insert into public.gs_motel_scheduled_meal_audit(meal_id,actor_id,old_status,new_status,reason)
 values(p_meal_id,auth.uid(),v_old,v_new,nullif(trim(coalesce(p_reason,'')),''));
 return v_new;
end; $$;
revoke all on function public.gs_staff_decide_motel_scheduled_meal(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_decide_motel_scheduled_meal(uuid,text,text) to authenticated;
