-- Upgrade 200: manager-only eligible employee and workload snapshot for a specific job.
-- No direct access to sensitive customer/order details is exposed.
create or replace function public.gs_list_eligible_table_job_workers(p_job_id bigint)
returns table(user_id uuid, full_name text, job_kind text, active_jobs bigint, kind_jobs bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_kind text; v_assigned uuid; v_status text;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 select j.kind,j.assigned_to,j.status into v_kind,v_assigned,v_status
 from public.gs_table_service_jobs j where j.id=p_job_id;
 if not found then raise exception 'Job not found'; end if;
 if v_status not in ('assigned','in_progress') then
  raise exception 'Only active assigned jobs can be reassigned';
 end if;
 if v_kind='deliver_items' and v_status='in_progress' then
  raise exception 'Delivery in progress requires verified handoff';
 end if;
 return query
 select p.user_id, coalesce(nullif(p.full_name,''),'Employee')::text,
   v_kind,
   (select count(*) from public.gs_table_service_jobs j
     where j.assigned_to=p.user_id and j.status in ('assigned','in_progress'))::bigint,
   (select count(*) from public.gs_table_service_jobs j
     where j.assigned_to=p.user_id and j.kind=v_kind
       and j.status in ('assigned','in_progress'))::bigint
 from public.employee_profiles p
 where p.is_active=true and p.user_id is distinct from v_assigned
   and public.gs_can_work_table_job(p.user_id,v_kind)
 order by 5 asc, 4 asc, p.full_name nulls last, p.user_id limit 500;
end; $$;
revoke all on function public.gs_list_eligible_table_job_workers(bigint) from public,anon;
grant execute on function public.gs_list_eligible_table_job_workers(bigint) to authenticated;
