-- Upgrade 54: visit-scoped cleaning and shisha safety foundation.
-- DRAFT ONLY. This does not override legacy checkout or release functions.
-- Existing legacy functions still need to be retired/reworked before deployment.

-- A service task must never claim to belong to a visit from another table.
create or replace function public.gs_validate_service_task_visit()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.table_visit_id is not null and not exists (
   select 1 from public.gs_table_visits v
   where v.id=new.table_visit_id and v.table_id=new.table_id
 ) then raise exception 'Service task visit does not match table'; end if;
 return new;
end; $$;
drop trigger if exists gs_service_task_visit_consistency on public.gs_table_service_tasks;
create trigger gs_service_task_visit_consistency
 before insert or update of table_visit_id,table_id on public.gs_table_service_tasks
 for each row execute function public.gs_validate_service_task_visit();

-- Read-only safety inspection for the current visit. This function is not a
-- payment authorization, a release action, or a claim of complete settlement.
create or replace function public.gs_dashboard_visit_cleaning_status(p_visit_id bigint)
returns table (
 visit_id bigint, table_id bigint, visit_status text,
 cleaning_required boolean, completed_cleaning_count bigint,
 pending_cleaning_count bigint, completed_shisha_pickup_count bigint,
 pending_shisha_pickup_count bigint, unlinked_task_count bigint,
 unlinked_order_count bigint, release_review_status text
)
language plpgsql stable security definer set search_path='' as $$
declare v_visit public.gs_table_visits%rowtype;
        v_table public.gs_cafe_tables%rowtype;
        v_clean_done bigint; v_clean_pending bigint;
        v_shisha_done bigint; v_shisha_pending bigint;
        v_unlinked_tasks bigint; v_unlinked_orders bigint;
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view')
    or not public.gs_can_access('tables','can_view') then
   raise exception 'Visit cleaning status access denied';
 end if;
 select * into v_visit from public.gs_table_visits where id=p_visit_id;
 if not found then raise exception 'Visit not found'; end if;
 select * into v_table from public.gs_cafe_tables where id=v_visit.table_id;
 select
  count(*) filter (where request_type='table_cleaning' and status='completed'),
  count(*) filter (where request_type='table_cleaning' and status<>'completed'),
  count(*) filter (where request_type='shisha_pickup' and status='completed'),
  count(*) filter (where request_type='shisha_pickup' and status<>'completed')
 into v_clean_done,v_clean_pending,v_shisha_done,v_shisha_pending
 from public.gs_table_service_tasks
 where table_visit_id=p_visit_id;
 select count(*) into v_unlinked_tasks
 from public.gs_table_service_tasks t
 where t.table_id=v_visit.table_id and t.table_visit_id is null
   and t.status not in ('completed','cancelled');
 select count(*) into v_unlinked_orders
 from public.gs_orders o
 where o.is_motel=false and o.destination=v_table.table_number::text
   and o.table_visit_id is null and o.status<>'cancelled';
 return query select v_visit.id,v_visit.table_id,v_visit.status::text,
   v_table.cleaning_needed,v_clean_done,v_clean_pending,
   v_shisha_done,v_shisha_pending,v_unlinked_tasks,v_unlinked_orders,
   (case
     when v_visit.status='closed' then 'already_closed'
     when not v_table.cleaning_needed or v_table.guests_departed_at is null
       then 'departure_or_cleaning_not_confirmed'
     when v_clean_done=0 or v_clean_pending>0 then 'cleaning_incomplete'
     when v_shisha_pending>0 then 'shisha_pickup_incomplete'
     when v_unlinked_tasks>0 or v_unlinked_orders>0 then 'unlinked_legacy_data_review'
     else 'tasks_complete_payment_and_release_still_unverified'
   end)::text;
end; $$;
revoke all on function public.gs_dashboard_visit_cleaning_status(bigint) from public,anon;
grant execute on function public.gs_dashboard_visit_cleaning_status(bigint) to authenticated;

-- No release RPC introduced: settlement across cash/card/credit/online and
-- verified owner waivers is still missing. Legacy release/checkout functions
-- remain unsafe for visit-specific operation and must be replaced atomically.
-- Never infer that no shisha pickup is required merely because no task exists.
