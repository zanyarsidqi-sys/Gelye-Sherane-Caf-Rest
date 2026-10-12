-- Upgrade 109: authoritative visit-scoped cleaning/shisha task list.
-- Prevent historical tasks from other visits on the same table appearing in UI.
create or replace function public.gs_visit_cleaning_tasks(p_visit_id bigint)
returns table(id bigint, request_type text, status text, notes text, created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Visit tasks permission denied'; end if;
 if p_visit_id is null or not exists (
   select 1 from public.gs_table_visits where gs_table_visits.id=p_visit_id) then
  raise exception 'Visit unavailable'; end if;
 return query
 select t.id,t.request_type,t.status,t.notes,t.created_at
 from public.gs_table_service_tasks t
 where t.table_visit_id=p_visit_id
  and t.request_type in ('table_cleaning','shisha_pickup')
 order by t.created_at desc,t.id desc limit 100;
end; $$;
revoke all on function public.gs_visit_cleaning_tasks(bigint) from public,anon;
grant execute on function public.gs_visit_cleaning_tasks(bigint) to authenticated;
