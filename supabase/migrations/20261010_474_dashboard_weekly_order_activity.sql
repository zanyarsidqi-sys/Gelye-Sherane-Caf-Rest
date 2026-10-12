-- Upgrade 474: seven-day, permission-scoped order counts for Section 01 Dashboard.
-- No monetary amounts or personal identifiers. No access to other order types.
create or replace function public.gs_dashboard_order_week()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_table boolean; v_motel boolean; v_result jsonb;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard','can_view') then
    raise exception 'Dashboard access denied' using errcode='42501';
  end if;
  v_table := public.gs_can_access('table_orders','can_view');
  v_motel := public.gs_can_access('motel_orders','can_view');
  select coalesce(jsonb_agg(jsonb_build_object('business_date',d.day::text,'order_count',
    (select count(*) from public.gs_orders o where
       o.created_at >= (d.day::timestamp at time zone 'Asia/Baghdad')
       and o.created_at < ((d.day+1)::timestamp at time zone 'Asia/Baghdad')
       and ((not o.is_motel and v_table) or (o.is_motel and v_motel)))) order by d.day), '[]'::jsonb)
    into v_result
  from generate_series(((now() at time zone 'Asia/Baghdad')::date-6),
                       (now() at time zone 'Asia/Baghdad')::date, interval '1 day') as d(day);
  return v_result;
end; $$;
revoke all on function public.gs_dashboard_order_week() from public, anon;
grant execute on function public.gs_dashboard_order_week() to authenticated;
