-- DRAFT: employee directory and durable in-app task notifications.
-- Run only after the task action RPC migration; review employee_profiles columns.
create or replace function public.gs_service_assignable_employees()
returns table(user_id uuid, full_name text)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Employee directory access denied';
 end if;
 return query
 select ep.user_id, coalesce(nullif(ep.full_name,''),'Employee')::text
 from public.employee_profiles ep
 where ep.is_active = true
 order by ep.full_name nulls last, ep.user_id
 limit 500;
end; $$;
revoke all on function public.gs_service_assignable_employees() from public,anon;
grant execute on function public.gs_service_assignable_employees() to authenticated;

create table if not exists public.gs_service_task_notifications(
 id bigint generated always as identity primary key,
 task_id bigint not null references public.gs_table_service_tasks(id),
 recipient_id uuid not null references auth.users(id),
 event_type text not null check(event_type in ('assigned','reassigned','status_changed')),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists gs_service_task_notifications_recipient_idx
 on public.gs_service_task_notifications(recipient_id,created_at desc);
alter table public.gs_service_task_notifications enable row level security;
revoke all on public.gs_service_task_notifications from anon,authenticated;
-- Enqueue within the same transaction as assignment or status changes.
create or replace function public.gs_enqueue_service_task_notification()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if new.assigned_employee_id is not null and
   (old.assigned_employee_id is distinct from new.assigned_employee_id) then
   insert into public.gs_service_task_notifications(task_id,recipient_id,event_type)
   values(new.id,new.assigned_employee_id,
     case when old.assigned_employee_id is null then 'assigned' else 'reassigned' end);
 elsif new.assigned_employee_id is not null and old.status is distinct from new.status then
   insert into public.gs_service_task_notifications(task_id,recipient_id,event_type)
   values(new.id,new.assigned_employee_id,'status_changed');
 end if;
 return new;
end; $$;
drop trigger if exists gs_service_task_notification_trigger on public.gs_table_service_tasks;
create trigger gs_service_task_notification_trigger
 after update of assigned_employee_id,status on public.gs_table_service_tasks
 for each row execute function public.gs_enqueue_service_task_notification();

-- Only recipient can read notification summaries via permission-checked RPC.
create or replace function public.gs_my_service_task_notifications(p_limit int default 50)
returns table(id bigint, task_id bigint, event_type text, created_at timestamptz, read_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 return query
 select n.id,n.task_id,n.event_type,n.created_at,n.read_at
 from public.gs_service_task_notifications n
 where n.recipient_id=auth.uid()
 order by n.created_at desc
 limit least(greatest(coalesce(p_limit,50),1),100);
end; $$;
revoke all on function public.gs_my_service_task_notifications(int) from public,anon;
grant execute on function public.gs_my_service_task_notifications(int) to authenticated;
-- No push delivery, read-acknowledgment UI, or offline retry implemented yet.
