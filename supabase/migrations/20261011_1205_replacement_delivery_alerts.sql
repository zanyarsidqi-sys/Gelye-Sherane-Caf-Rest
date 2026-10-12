-- Upgrade 1205: supervisor-only employee picker and permission-scoped overdue alerts.
-- No direct grants on delivery task tables. Poll existing permission-filtered RPCs.
create or replace function public.gs_replacement_delivery_eligible_employees(p_station_key text)
returns table(employee_id uuid,employee_name text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') or not exists (
   select 1 from public.gs_cafe_station_supervisors s
   where s.employee_id=auth.uid() and s.active
 ) then raise exception 'Supervisor permission required'; end if;
 return query select a.employee_id,coalesce(nullif(p.full_name,''),'Employee')::text
 from public.gs_cafe_station_employee_assignments a
 join public.employee_profiles p on p.user_id=a.employee_id and p.is_active=true
 where a.station_key=p_station_key and a.active
 order by p.full_name,a.employee_id limit 200;
end; $$;
revoke all on function public.gs_replacement_delivery_eligible_employees(text) from public,anon;
grant execute on function public.gs_replacement_delivery_eligible_employees(text) to authenticated;

create or replace function public.gs_replacement_delivery_overdue(p_threshold_minutes integer default 15)
returns table(revision_id bigint,order_id bigint,station_key text,ready_at timestamptz,
 assigned_to uuid,minutes_waiting integer,alert_kind text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required'; end if;
 if p_threshold_minutes < 1 or p_threshold_minutes > 240 then
   raise exception 'Invalid threshold'; end if;
 return query select r.id,r.order_id,r.station_key,r.preparation_ready_at,d.assigned_to,
 greatest(0,floor(extract(epoch from (transaction_timestamp()-r.preparation_ready_at))/60))::integer,
 case when d.assigned_to is null then 'unassigned' when d.accepted_at is null then 'not_accepted'
 when d.picked_up_at is null then 'awaiting_pickup' else 'awaiting_delivery' end::text
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 where d.delivered_at is null and r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes)
 and (d.assigned_to=auth.uid() or exists(select 1 from public.gs_cafe_station_supervisors s
 where s.employee_id=auth.uid() and s.active) or
 (d.assigned_to is null and public.gs_can_work_station(r.station_key)))
 order by r.preparation_ready_at limit 200;
end; $$;
revoke all on function public.gs_replacement_delivery_overdue(integer) from public,anon;
grant execute on function public.gs_replacement_delivery_overdue(integer) to authenticated;
