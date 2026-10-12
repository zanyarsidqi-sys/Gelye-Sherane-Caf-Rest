-- DRAFT: Deploy and verify only after all prerequisite migrations and permissions.
-- Operational metrics are derived from persisted records, not sample figures.
-- Missing source modules intentionally produce absent JSON keys, not zeroes.
create or replace function public.gs_dashboard_operational_metrics(p_day date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_day date := coalesce(p_day, (now() at time zone 'Asia/Baghdad')::date);
  v_result jsonb := '{}'::jsonb;
  v_count bigint;
  v_total bigint;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard', 'can_view') then
    raise exception 'Dashboard access denied';
  end if;

  if public.gs_can_access('tables', 'can_view') then
    select count(*), count(*) filter (where occupied)
      into v_total, v_count from public.gs_cafe_tables;
    -- Null when no tables are configured; do not claim 0% occupancy.
    if v_total > 0 then
      v_result := v_result || jsonb_build_object(
        'table_occupancy_percent', round((v_count::numeric * 100) / v_total, 1));
    end if;
  end if;

  if public.gs_can_access('table_orders', 'can_view')
      or public.gs_can_access('motel_orders', 'can_view') then
    -- Service target is a provisional 30 minutes, to be made configurable.
    -- Only orders from the requested Baghdad-local day are counted.
    select count(*) into v_count from public.gs_orders o
    where (o.created_at at time zone 'Asia/Baghdad')::date = v_day
      and o.status in ('new','preparing','ready')
      and o.created_at < now() - interval '30 minutes'
      and ((not o.is_motel and public.gs_can_access('table_orders','can_view'))
        or (o.is_motel and public.gs_can_access('motel_orders','can_view')));
    v_result := v_result || jsonb_build_object('overdue_service_orders', v_count);
  end if;

  if public.gs_can_access('menu', 'can_view')
      and (public.gs_can_access('table_orders','can_view')
        or public.gs_can_access('motel_orders','can_view')) then
    -- Unit count of the single most-ordered product for the selected day.
    select coalesce(max(product_units), 0) into v_count from (
      select sum(i.quantity)::bigint as product_units
      from public.gs_orders o
      join public.gs_order_items i on i.order_id = o.id
      where (o.created_at at time zone 'Asia/Baghdad')::date = v_day
        and o.status <> 'cancelled'
        and ((not o.is_motel and public.gs_can_access('table_orders','can_view'))
          or (o.is_motel and public.gs_can_access('motel_orders','can_view')))
      group by i.product_id
    ) product_totals;
    v_result := v_result || jsonb_build_object('top_product_units_sold', v_count);
  end if;

  if public.gs_can_access('action_center','can_view')
      and public.gs_can_access('customers','can_view') then
    select count(*) into v_count from public.gs_guest_feedback f
      where f.urgent and f.status not in ('resolved','closed');
    v_result := v_result || jsonb_build_object('urgent_actions_count', v_count);
  end if;

  return v_result;
end $$;
revoke all on function public.gs_dashboard_operational_metrics(date) from public, anon;
grant execute on function public.gs_dashboard_operational_metrics(date) to authenticated;
