-- DRAFT: authenticated notification acknowledgement and overdue task tracking.
-- Read acknowledgement is scoped to auth.uid(); no direct table update grants.
create or replace function public.gs_mark_service_notification_read(p_notification_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 update public.gs_service_task_notifications n
 set read_at=coalesce(n.read_at,now())
 where n.id=p_notification_id and n.recipient_id=auth.uid()
 returning n.id into v_id;
 return v_id is not null;
end; $$;
revoke all on function public.gs_mark_service_notification_read(bigint) from public,anon;
grant execute on function public.gs_mark_service_notification_read(bigint) to authenticated;

-- Overdue tracking is computed on demand, avoiding spam/duplicate reminder records.
-- Only the assignee sees their tasks; privileged users may use existing task queue.
create or replace function public.gs_my_overdue_service_tasks(p_after_minutes int default 15)
returns table(task_id bigint,table_id bigint,request_type text,status text,
              priority text,created_at timestamptz,minutes_waiting int)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 return query select t.id,t.table_id,t.request_type,t.status,t.priority,t.created_at,
  greatest(0,floor(extract(epoch from (now()-t.created_at))/60)::int)
 from public.gs_table_service_tasks t
 where t.assigned_employee_id=auth.uid()
   and t.status in ('assigned','accepted','in_progress')
   and t.created_at <= now()-make_interval(mins=>least(greatest(coalesce(p_after_minutes,15),1),1440))
 order by case when t.priority='urgent' then 0 else 1 end,t.created_at
 limit 100;
end; $$;
revoke all on function public.gs_my_overdue_service_tasks(int) from public,anon;
grant execute on function public.gs_my_overdue_service_tasks(int) to authenticated;
-- TODO: role-aware push delivery, configurable SLA, server-side reminder scheduling,
-- exact task navigation, background retry and full notification audit.
