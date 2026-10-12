-- Upgrade 472: fix cross-section data leakage in the operational dashboard.
-- Omitted keys mean not authorized, never zero. Baghdad-local date bounds.
create or replace function public.gs_dashboard_operational_summary()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb := jsonb_build_object('as_of',now(),'timezone','Asia/Baghdad');
  v_table_orders boolean; v_motel_orders boolean; v_kitchen boolean; v_tables boolean;
  v_start timestamptz := ((now() at time zone 'Asia/Baghdad')::date::timestamp at time zone 'Asia/Baghdad');
  v_end timestamptz := (((now() at time zone 'Asia/Baghdad')::date + 1)::timestamp at time zone 'Asia/Baghdad');
  v_count bigint; v_count2 bigint; v_count3 bigint;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard','can_view') then
    raise exception 'Dashboard access denied' using errcode='42501';
  end if;
  v_table_orders := public.gs_can_access('table_orders','can_view');
  v_motel_orders := public.gs_can_access('motel_orders','can_view');
  v_kitchen := public.gs_can_access('kitchen','can_view');
  v_tables := public.gs_can_access('tables','can_view');
  if v_table_orders or v_motel_orders then
    select count(*) into v_count from public.gs_orders o
    where o.created_at >= v_start and o.created_at < v_end
      and ((not o.is_motel and v_table_orders) or (o.is_motel and v_motel_orders));
    v_result := v_result || jsonb_build_object('today_orders',v_count);
  end if;
  if v_table_orders then
    select count(*) into v_count from public.gs_orders o
    where not o.is_motel and o.created_at >= v_start and o.created_at < v_end;
    v_result := v_result || jsonb_build_object('today_table_orders',v_count);
  end if;
  if v_motel_orders then
    select count(*) into v_count from public.gs_orders o
    where o.is_motel and o.created_at >= v_start and o.created_at < v_end;
    v_result := v_result || jsonb_build_object('today_motel_orders',v_count);
  end if;
  if v_kitchen then
    select count(*) filter (where o.status in ('new','preparing')),
           count(*) filter (where o.status='ready') into v_count,v_count2
    from public.gs_orders o where o.created_at >= v_start and o.created_at < v_end;
    v_result := v_result || jsonb_build_object('pending_kitchen',v_count,'ready_orders',v_count2);
  end if;
  if v_tables then
    select count(*), count(*) filter (where occupied),
           count(*) filter (where occupied and tourism_mode)
      into v_count,v_count2,v_count3 from public.gs_cafe_tables;
    v_result := v_result || jsonb_build_object('total_tables',v_count,
      'occupied_tables',v_count2,'tourism_tables',v_count3);
  end if;
  return v_result;
end;$$;
revoke all on function public.gs_dashboard_operational_summary() from public, anon;
grant execute on function public.gs_dashboard_operational_summary() to authenticated;
