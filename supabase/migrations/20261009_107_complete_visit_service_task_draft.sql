-- Upgrade 107: ACTUAL authorized completion of a visit-bound cleaning/shisha task.
-- This completes a real service task but never certifies payment or releases a table.
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
 if not found or v_visit.status<>'cleaning' then
  raise exception 'Visit is not in authorized cleaning stage'; end if;
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
 update public.gs_table_service_tasks
 set status='completed', notes=left(concat_ws(' | ',nullif(notes,''),
  'Completion note: '||coalesce(nullif(trim(p_completion_note),''),'none')),1000)
 where id=v_task.id;
 -- Intentionally DO NOT update occupied, cleaning_needed, visit status,
 -- cash, ledger, or order status. Table release remains separately gated.
 return v_task.id;
end; $$;
revoke all on function public.gs_complete_visit_service_task(bigint,bigint,text)
 from public,anon;
grant execute on function public.gs_complete_visit_service_task(bigint,bigint,text)
 to authenticated;
