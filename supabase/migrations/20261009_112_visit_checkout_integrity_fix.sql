-- Upgrade 112: enforce visit/table integrity in physical checkout readiness.
-- Upgrade 110: physical checkout completion status, without bypassing finance.
-- Authoritative visit-specific tasks; table release remains prohibited until
-- independent payment settlement is implemented and tested.
create or replace function public.gs_visit_physical_checkout_status(p_visit_id bigint)
returns table (
 visit_id bigint, table_id bigint, guests_departed boolean,
 cleaning_required boolean, cleaning_completed boolean,
 shisha_required boolean, shisha_completed boolean,
 physical_ready boolean, blocking_reason text
)
language plpgsql stable security definer set search_path='' as $$
declare v_visit public.gs_table_visits%rowtype;
 v_table public.gs_cafe_tables%rowtype;
 v_clean_total bigint;v_clean_done bigint;v_shisha_total bigint;v_shisha_done bigint;
 v_ready boolean; v_conflicting_visits bigint; v_wrong_table_tasks bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table inspection permission denied';
 end if;
 select * into v_visit from public.gs_table_visits where id=p_visit_id;
 if not found then raise exception 'Visit not found'; end if;
 select * into v_table from public.gs_cafe_tables where id=v_visit.table_id;
 if not found then raise exception 'Table not found'; end if;
 select count(*) filter (where request_type='table_cleaning'),
        count(*) filter (where request_type='table_cleaning' and status='completed'),
        count(*) filter (where request_type='shisha_pickup'),
        count(*) filter (where request_type='shisha_pickup' and status='completed')
 into v_clean_total,v_clean_done,v_shisha_total,v_shisha_done
 from public.gs_table_service_tasks
 where table_visit_id=p_visit_id and table_id=v_visit.table_id and status<>'cancelled'
  and request_type in ('table_cleaning','shisha_pickup');
 -- A reused table's departure timestamp must never certify a different
 -- simultaneously open visit; reject any ambiguous active-visit state.
 select count(*) into v_conflicting_visits
 from public.gs_table_visits x where x.table_id=v_visit.table_id
 and x.id<>v_visit.id and x.status in ('active','cleaning');
 -- Tasks with a mismatched physical table cannot certify this visit.
 select count(*) into v_wrong_table_tasks
 from public.gs_table_service_tasks x where x.table_visit_id=p_visit_id
 and x.table_id is distinct from v_visit.table_id and x.status<>'cancelled';
 v_ready:=v_conflicting_visits=0 and v_wrong_table_tasks=0
  and v_table.occupied and v_table.guests_departed_at is not null
  and v_table.cleaning_needed and v_clean_total>0
  and v_clean_done=v_clean_total and v_shisha_done=v_shisha_total
  and v_visit.status in ('active','cleaning');
 return query select v_visit.id,v_visit.table_id,
  v_table.guests_departed_at is not null,v_table.cleaning_needed,
  (v_clean_total>0 and v_clean_done=v_clean_total),
  (v_shisha_total>0),
  (v_shisha_done=v_shisha_total),
  v_ready,
  case when v_conflicting_visits>0 then 'Conflicting active table visits'
   when v_wrong_table_tasks>0 then 'Visit has service tasks linked to another table'
   when not v_table.occupied then 'Table is not occupied'
   when v_visit.status not in ('active','cleaning') then 'Visit is not open'
   when v_table.guests_departed_at is null then 'Guests have not departed'
   when not v_table.cleaning_needed or v_clean_total=0 then 'Cleaning not requested'
   when v_clean_done<v_clean_total then 'Cleaning not complete'
   when v_shisha_done<v_shisha_total then 'Shisha pickup not complete'
   else 'Physical tasks complete; independent financial settlement still required'
  end::text;
end; $$;
revoke all on function public.gs_visit_physical_checkout_status(bigint) from public,anon;
grant execute on function public.gs_visit_physical_checkout_status(bigint) to authenticated;
