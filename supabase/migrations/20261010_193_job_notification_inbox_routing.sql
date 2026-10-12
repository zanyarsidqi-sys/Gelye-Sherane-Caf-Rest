-- Upgrade 193: transactional routing of job events into the employee inbox.
-- No external push dispatch; events become visible on refresh.
alter table public.gs_table_work_notifications
 add column if not exists source_job_event_id bigint
 references public.gs_table_service_job_events(id);
create unique index if not exists gs_work_notification_source_job_event_unique
 on public.gs_table_work_notifications(source_job_event_id,recipient_employee)
 where source_job_event_id is not null and recipient_employee is not null;

create or replace function public.gs_route_table_job_event_to_inbox()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_table_number integer; v_kind text; v_assigned uuid;
 v_message text;
begin
 select j.table_number,j.kind,j.assigned_to
 into v_table_number,v_kind,v_assigned
 from public.gs_table_service_jobs j where j.id=new.job_id;
 if v_table_number is null then return new; end if;
 v_message:='Table '||v_table_number||' · '||replace(new.event_kind,'_',' ')||
   ' · '||replace(v_kind,'_',' ')||' · job #'||new.job_id;
 -- Notify the assigned worker when the job is claimed or assigned.
 if new.event_kind in ('job_claimed','job_assigned','job_reassigned')
    and v_assigned is not null then
  insert into public.gs_table_work_notifications(
    event_type,job_id,table_number,recipient_employee,actor,message,source_job_event_id)
  values(new.event_kind,new.job_id,v_table_number,v_assigned,new.actor,
    v_message,new.id)
  on conflict do nothing;
 end if;
 -- Notify the job creator / event recipient about progress, if different.
 if new.recipient is not null and new.recipient is distinct from v_assigned then
  insert into public.gs_table_work_notifications(
    event_type,job_id,table_number,recipient_employee,actor,message,source_job_event_id)
  values(new.event_kind,new.job_id,v_table_number,new.recipient,new.actor,
    v_message,new.id)
  on conflict do nothing;
 end if;
 return new;
end; $$;
drop trigger if exists gs_route_table_job_event_to_inbox_trigger
 on public.gs_table_service_job_events;
create trigger gs_route_table_job_event_to_inbox_trigger
 after insert on public.gs_table_service_job_events
 for each row execute function public.gs_route_table_job_event_to_inbox();

-- Backfill only targeted job events. Never broadcast employee-private assignments.
insert into public.gs_table_work_notifications(
 event_type,job_id,table_number,recipient_employee,actor,message,source_job_event_id)
select e.event_kind,j.id,j.table_number,j.assigned_to,e.actor,
 'Table '||j.table_number||' · '||replace(e.event_kind,'_',' ')||
 ' · '||replace(j.kind,'_',' ')||' · job #'||j.id,e.id
from public.gs_table_service_job_events e
join public.gs_table_service_jobs j on j.id=e.job_id
where e.event_kind in ('job_claimed','job_assigned','job_reassigned')
 and j.assigned_to is not null
on conflict do nothing;
