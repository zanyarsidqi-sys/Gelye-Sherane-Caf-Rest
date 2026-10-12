-- DRAFT. Apply after 036 audit foundation and 039 service task foundation.
-- Server-enforced cashier/manager assignment and employee status transitions.
-- No direct client writes to task or audit tables.
create or replace function public.gs_assign_table_service_task(
  p_task_id bigint, p_employee_id uuid
) returns void
language plpgsql security definer set search_path=''
as $$
declare v_task public.gs_table_service_tasks%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Assignment permission denied';
 end if;
 if p_employee_id is null or not exists (
   select 1 from auth.users u where u.id=p_employee_id
 ) then raise exception 'Unknown employee'; end if;
 select * into v_task from public.gs_table_service_tasks
 where id=p_task_id for update;
 if not found then raise exception 'Service task not found'; end if;
 if v_task.status in ('completed','cancelled') then
   raise exception 'Cannot assign closed task';
 end if;
 if v_task.assigned_employee_id is not distinct from p_employee_id then return; end if;
 update public.gs_table_service_tasks
 set assigned_employee_id=p_employee_id,status='assigned',updated_at=now()
 where id=p_task_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,before_data,after_data)
 values (auth.uid(),'tables','service_task_assigned',p_task_id::text,
 jsonb_build_object('assignee',v_task.assigned_employee_id,'status',v_task.status),
 jsonb_build_object('assignee',p_employee_id,'status','assigned'));
end; $$;

create or replace function public.gs_update_table_service_task_status(
 p_task_id bigint, p_new_status text
) returns void
language plpgsql security definer set search_path=''
as $$
declare v_task public.gs_table_service_tasks%rowtype;
declare v_manager boolean;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 select * into v_task from public.gs_table_service_tasks
 where id=p_task_id for update;
 if not found then raise exception 'Service task not found'; end if;
 v_manager := public.gs_can_access('tables','can_edit');
 if not v_manager and v_task.assigned_employee_id is distinct from auth.uid() then
   raise exception 'Task not assigned to you';
 end if;
 if not (
   (v_task.status='assigned' and p_new_status='accepted') or
   (v_task.status='accepted' and p_new_status='in_progress') or
   (v_task.status='in_progress' and p_new_status='completed') or
   (v_manager and v_task.status in ('pending','assigned','accepted','in_progress')
     and p_new_status='cancelled')
 ) then raise exception 'Invalid task status transition'; end if;
 update public.gs_table_service_tasks set status=p_new_status,
 updated_at=now(),completed_at=case when p_new_status='completed' then now() else null end
 where id=p_task_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,before_data,after_data)
 values(auth.uid(),'tables','service_task_status_changed',p_task_id::text,
 jsonb_build_object('status',v_task.status),
 jsonb_build_object('status',p_new_status));
end; $$;
revoke all on function public.gs_assign_table_service_task(bigint,uuid) from public,anon;
revoke all on function public.gs_update_table_service_task_status(bigint,text) from public,anon;
grant execute on function public.gs_assign_table_service_task(bigint,uuid) to authenticated;
grant execute on function public.gs_update_table_service_task_status(bigint,text) to authenticated;
-- Important: notification delivery, active employee verification, task creation,
-- auto-cleaning and release guards still require dedicated migrations and testing.
