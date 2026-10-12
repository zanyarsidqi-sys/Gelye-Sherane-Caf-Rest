-- Upgrade 108: REAL physical departure + visit-scoped service-task initiation.
-- This is NOT checkout or financial settlement; table remains occupied.
-- Physical cleaning can occur while financial exceptions remain outstanding.
create or replace function public.gs_record_visit_guest_departure(
 p_visit_id bigint, p_shisha_pickup_required boolean default false)
returns table(cleaning_task_id bigint, shisha_task_id bigint)
language plpgsql security definer set search_path='' as $$
declare v_visit public.gs_table_visits%rowtype;
 v_table public.gs_cafe_tables%rowtype;
 v_clean bigint; v_shisha bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Guest departure permission denied'; end if;
 if p_visit_id is null then raise exception 'Visit required'; end if;
 select * into v_visit from public.gs_table_visits where id=p_visit_id for update;
 if not found or v_visit.status not in ('active','cleaning') then
  raise exception 'Visit is not active or cleaning'; end if;
 select * into v_table from public.gs_cafe_tables where id=v_visit.table_id for update;
 if not found or not v_table.occupied then raise exception 'Table is not occupied'; end if;
 if exists(select 1 from public.gs_table_visits x where x.table_id=v_table.id
    and x.id<>v_visit.id and x.status in ('active','cleaning')) then
  raise exception 'Conflicting active/cleaning table visit'; end if;
 -- Physical departure is recorded independently from payment settlement.
 update public.gs_cafe_tables set guests_departed_at=coalesce(guests_departed_at,now()),
  cleaning_needed=true,updated_at=now(),updated_by=auth.uid()
 where id=v_table.id;
 -- Lock existing task before creating a new one; serialize via visit row lock.
 select id into v_clean from public.gs_table_service_tasks
 where table_visit_id=p_visit_id and request_type='table_cleaning'
  and status<>'cancelled' order by id desc limit 1;
 if v_clean is null then
  insert into public.gs_table_service_tasks
    (table_id,table_visit_id,request_type,created_by,priority,notes)
  values(v_table.id,p_visit_id,'table_cleaning',auth.uid(),'urgent',
    'Guest departed; physical cleaning required; payment NOT certified')
  returning id into v_clean;
 end if;
 if coalesce(p_shisha_pickup_required,false) then
  select id into v_shisha from public.gs_table_service_tasks
  where table_visit_id=p_visit_id and request_type='shisha_pickup'
   and status<>'cancelled' order by id desc limit 1;
  if v_shisha is null then
   insert into public.gs_table_service_tasks
     (table_id,table_visit_id,request_type,created_by,priority,notes)
   values(v_table.id,p_visit_id,'shisha_pickup',auth.uid(),'urgent',
     'Staff confirmed shisha pickup required; payment NOT certified')
   returning id into v_shisha;
  end if;
 end if;
 return query select v_clean,v_shisha;
end; $$;
revoke all on function public.gs_record_visit_guest_departure(bigint,boolean) from public,anon;
grant execute on function public.gs_record_visit_guest_departure(bigint,boolean) to authenticated;

-- Upgrade 107 completion was inaccessible because no settlement-to-cleaning
-- transition exists. Permit completion during active visits only AFTER a
-- physical departure has been recorded and cleaning has been requested.
-- No visit status transition, financial posting, or table release occurs.
create or replace function public.gs_complete_visit_service_task(
 p_task_id bigint, p_visit_id bigint, p_completion_note text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_task public.gs_table_service_tasks%rowtype;
 v_visit public.gs_table_visits%rowtype;
 v_table public.gs_cafe_tables%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Service completion permission denied'; end if;
 if p_task_id is null or p_visit_id is null then raise exception 'Task and visit required'; end if;
 if p_completion_note is not null and length(p_completion_note)>500 then
  raise exception 'Completion note too long'; end if;
 select * into v_visit from public.gs_table_visits where id=p_visit_id for update;
 if not found or v_visit.status not in ('active','cleaning') then
  raise exception 'Visit is not active or cleaning'; end if;
 select * into v_table from public.gs_cafe_tables where id=v_visit.table_id for update;
 if not found or not v_table.occupied or not v_table.cleaning_needed
    or v_table.guests_departed_at is null then
  raise exception 'Guest departure and cleaning state must be confirmed'; end if;
 select * into v_task from public.gs_table_service_tasks where id=p_task_id for update;
 if not found or v_task.table_id<>v_visit.table_id
    or v_task.table_visit_id is distinct from p_visit_id
    or v_task.request_type not in ('table_cleaning','shisha_pickup') then
  raise exception 'Task does not belong to this visit'; end if;
 if v_task.status='completed' then return v_task.id; end if;
 if v_task.status='cancelled' then raise exception 'Cancelled task cannot be completed'; end if;
 update public.gs_table_service_tasks set status='completed',
  notes=left(concat_ws(' | ',nullif(notes,''),
   'Completion note: '||coalesce(nullif(trim(p_completion_note),''),'none')),1000)
 where id=v_task.id;
 return v_task.id;
end; $$;
revoke all on function public.gs_complete_visit_service_task(bigint,bigint,text) from public,anon;
grant execute on function public.gs_complete_visit_service_task(bigint,bigint,text) to authenticated;
