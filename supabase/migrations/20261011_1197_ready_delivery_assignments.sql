-- Upgrade 1197: durable ready-to-deliver work items, assigned to an employee.
create table if not exists public.gs_cafe_delivery_tasks (
 ticket_id bigint primary key references public.gs_cafe_order_station_tickets(id),
 created_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id),
 assigned_by uuid references auth.users(id),
 assigned_at timestamptz,
 accepted_at timestamptz,
 updated_at timestamptz not null default transaction_timestamp()
);
create table if not exists public.gs_cafe_delivery_task_events (
 id bigint generated always as identity primary key,
 ticket_id bigint not null references public.gs_cafe_order_station_tickets(id),
 actor_id uuid references auth.users(id),
 event_kind text not null check(event_kind in ('ready','assigned','accepted')),
 event_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id)
);
alter table public.gs_cafe_delivery_tasks enable row level security;
alter table public.gs_cafe_delivery_task_events enable row level security;
revoke all on public.gs_cafe_delivery_tasks,public.gs_cafe_delivery_task_events from public,anon,authenticated;

create or replace function public.gs_enqueue_station_delivery()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.state='ready' and old.state is distinct from 'ready' then
  insert into public.gs_cafe_delivery_tasks(ticket_id) values(new.ticket_id)
  on conflict(ticket_id) do nothing;
  insert into public.gs_cafe_delivery_task_events(ticket_id,actor_id,event_kind)
  values(new.ticket_id,new.ready_by,'ready');
 end if;
 return new;
end; $$;
drop trigger if exists gs_enqueue_station_delivery on public.gs_cafe_station_preparation;
create trigger gs_enqueue_station_delivery after update of state on public.gs_cafe_station_preparation
for each row execute function public.gs_enqueue_station_delivery();
revoke all on function public.gs_enqueue_station_delivery() from public,anon,authenticated;
-- Include tickets already ready before this migration.
insert into public.gs_cafe_delivery_tasks(ticket_id)
select p.ticket_id from public.gs_cafe_station_preparation p where p.state='ready'
on conflict(ticket_id) do nothing;

create or replace function public.gs_assign_delivery_employee(p_ticket_id bigint,p_employee_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text; v_task public.gs_cafe_delivery_tasks%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or
  not exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 then raise exception 'Supervisor authorization required'; end if;
 select t.station_key into v_station from public.gs_cafe_order_station_tickets t where t.id=p_ticket_id;
 if v_station is null or p_employee_id is null or not exists(
  select 1 from public.gs_cafe_station_employee_assignments a
  where a.station_key=v_station and a.employee_id=p_employee_id and a.active)
 then raise exception 'Active employee assignment for this station required'; end if;
 select * into v_task from public.gs_cafe_delivery_tasks where ticket_id=p_ticket_id for update;
 if not found or exists(select 1 from public.gs_cafe_station_preparation p
   where p.ticket_id=p_ticket_id and p.picked_up_at is not null)
 then raise exception 'Ticket is not awaiting pickup'; end if;
 update public.gs_cafe_delivery_tasks set assigned_to=p_employee_id,assigned_by=auth.uid(),
  assigned_at=transaction_timestamp(),accepted_at=null,updated_at=transaction_timestamp()
 where ticket_id=p_ticket_id;
 insert into public.gs_cafe_delivery_task_events(ticket_id,actor_id,event_kind,assigned_to)
 values(p_ticket_id,auth.uid(),'assigned',p_employee_id);
end; $$;
revoke all on function public.gs_assign_delivery_employee(bigint,uuid) from public,anon;
grant execute on function public.gs_assign_delivery_employee(bigint,uuid) to authenticated;

create or replace function public.gs_accept_delivery_assignment(p_ticket_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_task public.gs_cafe_delivery_tasks%rowtype; v_station text;
begin
 select * into v_task from public.gs_cafe_delivery_tasks where ticket_id=p_ticket_id for update;
 select station_key into v_station from public.gs_cafe_order_station_tickets where id=p_ticket_id;
 if auth.uid() is null or not public.gs_can_work_station(v_station)
  or not found or v_task.assigned_to is distinct from auth.uid()
  or v_task.accepted_at is not null
  or exists(select 1 from public.gs_cafe_station_preparation p where p.ticket_id=p_ticket_id and p.picked_up_at is not null)
 then raise exception 'Not an eligible assigned delivery employee'; end if;
 update public.gs_cafe_delivery_tasks set accepted_at=transaction_timestamp(),updated_at=transaction_timestamp()
 where ticket_id=p_ticket_id;
 insert into public.gs_cafe_delivery_task_events(ticket_id,actor_id,event_kind,assigned_to)
 values(p_ticket_id,auth.uid(),'accepted',auth.uid());
end; $$;
revoke all on function public.gs_accept_delivery_assignment(bigint) from public,anon;
grant execute on function public.gs_accept_delivery_assignment(bigint) to authenticated;

-- Require assignment acceptance for station pickup; retain legacy handover validation.
create or replace function public.gs_delivery_pickup_assignment_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.picked_up_at is null and new.picked_up_at is not null and
  not exists(select 1 from public.gs_cafe_delivery_tasks d
    where d.ticket_id=new.ticket_id and d.assigned_to=auth.uid() and d.accepted_at is not null)
 then raise exception 'Accept your delivery assignment before pickup'; end if;
 return new;
end; $$;
drop trigger if exists gs_delivery_pickup_assignment_guard on public.gs_cafe_station_preparation;
create trigger gs_delivery_pickup_assignment_guard before update of picked_up_at on public.gs_cafe_station_preparation
for each row execute function public.gs_delivery_pickup_assignment_guard();
revoke all on function public.gs_delivery_pickup_assignment_guard() from public,anon,authenticated;

create or replace function public.gs_list_ready_delivery_tasks()
returns table(ticket_id bigint,order_id bigint,station_key text,station_name text,
 ready_at timestamptz,assigned_to uuid,accepted_at timestamptz,picked_up_at timestamptz,delivered_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 return query select t.id,t.order_id,t.station_key,s.display_name,p.ready_at,
  d.assigned_to,d.accepted_at,p.picked_up_at,p.delivered_at
 from public.gs_cafe_delivery_tasks d
 join public.gs_cafe_order_station_tickets t on t.id=d.ticket_id
 join public.gs_cafe_preparation_stations s on s.station_key=t.station_key
 join public.gs_cafe_station_preparation p on p.ticket_id=t.id
 join public.gs_orders o on o.id=t.order_id
 where p.delivered_at is null and o.status in ('preparing','ready') and (
   exists(select 1 from public.gs_cafe_station_supervisors sup where sup.employee_id=auth.uid() and sup.active)
   or d.assigned_to=auth.uid()
   or (d.assigned_to is null and exists(select 1 from public.gs_cafe_station_employee_assignments a
     where a.station_key=t.station_key and a.employee_id=auth.uid() and a.active)))
 order by p.ready_at,t.id limit 200;
end; $$;
revoke all on function public.gs_list_ready_delivery_tasks() from public,anon;
grant execute on function public.gs_list_ready_delivery_tasks() to authenticated;
