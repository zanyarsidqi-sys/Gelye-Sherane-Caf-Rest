-- Read-only aggregate. No customer details, payment totals or row-level identifiers exposed.
create or replace function public.gs_dashboard_operational_summary()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_orders bigint; v_table_orders bigint; v_motel_orders bigint;
 v_pending bigint; v_ready bigint; v_tables bigint; v_occupied bigint; v_tourism bigint;
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view') then
   raise exception 'Dashboard access denied' using errcode='42501';
 end if;
 select count(*), count(*) filter (where not is_motel), count(*) filter (where is_motel),
 count(*) filter (where status in ('new','preparing')),
 count(*) filter (where status='ready')
 into v_orders,v_table_orders,v_motel_orders,v_pending,v_ready
 from public.gs_orders where created_at >= (now() at time zone 'Asia/Baghdad')::date at time zone 'Asia/Baghdad';
 select count(*),count(*) filter (where occupied),count(*) filter (where occupied and tourism_mode)
 into v_tables,v_occupied,v_tourism from public.gs_cafe_tables;
 return jsonb_build_object('today_orders',v_orders,'today_table_orders',v_table_orders,
 'today_motel_orders',v_motel_orders,'pending_kitchen',v_pending,'ready_orders',v_ready,
 'total_tables',v_tables,'occupied_tables',v_occupied,'tourism_tables',v_tourism,
 'as_of',now(),'timezone','Asia/Baghdad');
end;$$;
revoke all on function public.gs_dashboard_operational_summary() from public;
grant execute on function public.gs_dashboard_operational_summary() to authenticated;
