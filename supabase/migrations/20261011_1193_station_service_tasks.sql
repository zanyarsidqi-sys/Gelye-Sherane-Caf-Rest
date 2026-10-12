-- Upgrade 1193: authorized, timestamped table service and cleaning tasks.
create table if not exists public.gs_cafe_service_tasks (
 id bigint generated always as identity primary key,
 table_label text not null check (char_length(btrim(table_label)) between 1 and 80),
 task_type text not null check (task_type in ('dish_pickup','table_cleaning','utensils','napkins','water','shisha_coal','other')),
 notes text check (notes is null or char_length(notes) <= 500),
 status text not null default 'new' check (status in ('new','assigned','accepted','completed','cancelled')),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id),
 assigned_by uuid references auth.users(id),
 assigned_at timestamptz,
 accepted_at timestamptz,
 completed_at timestamptz,
 cancelled_at timestamptz,
 updated_at timestamptz not null default transaction_timestamp()
);
create table if not exists public.gs_cafe_service_task_events (
 id bigint generated always as identity primary key,
 task_id bigint not null references public.gs_cafe_service_tasks(id),
 event_type text not null,
 actor_id uuid not null references auth.users(id),
 event_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id),
 notes text
);
alter table public.gs_cafe_service_tasks enable row level security;
alter table public.gs_cafe_service_task_events enable row level security;
revoke all on public.gs_cafe_service_tasks,public.gs_cafe_service_task_events from public,anon,authenticated;

create or replace function public.gs_create_service_task(p_table_label text,p_task_type text,p_notes text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not (public.gs_can_access('kitchen','can_edit') or public.gs_can_access('table_orders','can_edit')) then
   raise exception 'Not authorized to create service tasks'; end if;
 if p_table_label is null or char_length(btrim(p_table_label)) not between 1 and 80
    or p_task_type is null or p_task_type not in ('dish_pickup','table_cleaning','utensils','napkins','water','shisha_coal','other')
    or char_length(coalesce(p_notes,'')) > 500 then raise exception 'Invalid service task'; end if;
 insert into public.gs_cafe_service_tasks(table_label,task_type,notes,requested_by)
 values(btrim(p_table_label),p_task_type,nullif(btrim(p_notes),''),auth.uid()) returning id into v_id;
 insert into public.gs_cafe_service_task_events(task_id,event_type,actor_id) values(v_id,'created',auth.uid());
 return v_id;
end; $$;

create or replace function public.gs_transition_service_task(p_task_id bigint,p_action text,p_employee_id uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v public.gs_cafe_service_tasks%rowtype;
declare v_supervisor boolean;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then raise exception 'Kitchen edit permission required'; end if;
 select * into v from public.gs_cafe_service_tasks where id=p_task_id for update;
 if not found then raise exception 'Task not found'; end if;
 select exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 into v_supervisor;
 if p_action='assign' then
   if not v_supervisor or v.status not in ('new','assigned') or p_employee_id is null
      or not exists(select 1 from public.gs_cafe_station_employee_assignments a
                    where a.employee_id=p_employee_id and a.active) then
      raise exception 'Supervisor and active assigned employee required'; end if;
   update public.gs_cafe_service_tasks set status='assigned',assigned_to=p_employee_id,
     assigned_by=auth.uid(),assigned_at=transaction_timestamp(),accepted_at=null,
     updated_at=transaction_timestamp() where id=p_task_id;
 elsif p_action='accept' then
   if v.status <> 'assigned' or v.assigned_to is distinct from auth.uid() then
     raise exception 'Only the assigned employee can accept this task'; end if;
   update public.gs_cafe_service_tasks set status='accepted',accepted_at=transaction_timestamp(),
     updated_at=transaction_timestamp() where id=p_task_id;
 elsif p_action='complete' then
   if v.status <> 'accepted' or v.assigned_to is distinct from auth.uid() then
     raise exception 'Only the assigned employee can complete an accepted task'; end if;
   update public.gs_cafe_service_tasks set status='completed',completed_at=transaction_timestamp(),
     updated_at=transaction_timestamp() where id=p_task_id;
 elsif p_action='cancel' then
   if not v_supervisor or v.status in ('completed','cancelled') then
     raise exception 'Supervisor required to cancel an active task'; end if;
   update public.gs_cafe_service_tasks set status='cancelled',cancelled_at=transaction_timestamp(),
     updated_at=transaction_timestamp() where id=p_task_id;
 else raise exception 'Unknown task action'; end if;
 insert into public.gs_cafe_service_task_events(task_id,event_type,actor_id,assigned_to)
 values(p_task_id,p_action,auth.uid(),case when p_action='assign' then p_employee_id else v.assigned_to end);
end; $$;

create or replace function public.gs_list_service_tasks(p_limit integer default 100)
returns table(id bigint,table_label text,task_type text,notes text,status text,requested_by uuid,
 requested_at timestamptz,assigned_to uuid,assigned_at timestamptz,accepted_at timestamptz,completed_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select t.id,t.table_label,t.task_type,t.notes,t.status,t.requested_by,t.requested_at,
 t.assigned_to,t.assigned_at,t.accepted_at,t.completed_at
 from public.gs_cafe_service_tasks t order by t.requested_at desc,t.id desc limit least(greatest(coalesce(p_limit,100),1),250);
end; $$;

create or replace function public.gs_service_task_history(p_task_id bigint)
returns table(event_type text,actor_id uuid,event_at timestamptz,assigned_to uuid)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select e.event_type,e.actor_id,e.event_at,e.assigned_to
 from public.gs_cafe_service_task_events e where e.task_id=p_task_id order by e.event_at,e.id;
end; $$;
revoke all on function public.gs_create_service_task(text,text,text), public.gs_transition_service_task(bigint,text,uuid),
 public.gs_list_service_tasks(integer),public.gs_service_task_history(bigint) from public,anon;
grant execute on function public.gs_create_service_task(text,text,text), public.gs_transition_service_task(bigint,text,uuid),
 public.gs_list_service_tasks(integer),public.gs_service_task_history(bigint) to authenticated;
