-- Section 1: permission-filtered management dashboard; amounts are IQD.
-- Order value is NOT revenue received. Cash is the only integrated payment channel.
create or replace function public.gs_dashboard_overview(p_day date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_day date := coalesce(p_day, (now() at time zone 'Asia/Baghdad')::date);
  v_orders boolean;
  v_motel boolean;
  v_kitchen boolean;
  v_finance boolean;
  v_inventory boolean;
  v_result jsonb := jsonb_build_object('day',v_day);
  v_count bigint;
  v_total bigint;
  v_paid bigint;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard') then
    raise exception 'Dashboard access denied';
  end if;
  v_orders := public.gs_can_access('table_orders');
  v_motel := public.gs_can_access('motel_orders');
  v_kitchen := public.gs_can_access('kitchen');
  v_finance := public.gs_can_access('invoices_payments') or public.gs_can_access('payments_management') or public.gs_can_access('revenue');
  v_inventory := public.gs_can_access('products_inventory');

  if v_orders or v_motel then
    select count(*), coalesce(sum(case when o.status <> 'cancelled' then coalesce(t.total,0) else 0 end),0)
      into v_count,v_total
    from public.gs_orders o
    left join lateral (select sum(i.line_total_iqd) as total from public.gs_order_items i where i.order_id=o.id) t on true
    where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('orders',v_count,'order_value_iqd',v_total);
    select count(*) into v_count from public.gs_orders o
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day and o.status<>'cancelled'
      and o.tourism_mode and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('tourism_orders',v_count);
    select count(*) into v_count from public.gs_orders o
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day and o.status not in ('served','cancelled')
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('active_orders',v_count);
  end if;
  if v_motel then
    select count(*) into v_count from public.gs_orders o where o.is_motel
      and (o.created_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('motel_orders',v_count);
  end if;
  if v_kitchen then
    select count(*) into v_count from public.gs_orders o where o.status in ('new','preparing','ready')
      and (o.created_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('kitchen_queue',v_count);
  end if;
  if v_finance then
    select coalesce(sum(p.amount_iqd),0) into v_paid from public.gs_cash_payments p
      where (p.collected_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('cash_collected_iqd',v_paid);
    -- Outstanding balance across non-cancelled orders created on selected day.
    select coalesce(sum(greatest(coalesce(t.total,0)-coalesce(p.paid,0),0)),0) into v_total
    from public.gs_orders o
    left join lateral (select sum(i.line_total_iqd) total from public.gs_order_items i where i.order_id=o.id) t on true
    left join lateral (select sum(c.amount_iqd) paid from public.gs_cash_payments c where c.order_id=o.id) p on true
    where (o.created_at at time zone 'Asia/Baghdad')::date=v_day and o.status<>'cancelled';
    v_result := v_result || jsonb_build_object('outstanding_iqd',v_total);
  end if;
  if v_inventory then
    -- Inventory overview is managed by migration 026. Keep dashboard independent
    -- of inventory schema changes; inventory detail remains in its own section.
    v_result := v_result || jsonb_build_object('inventory_link',true);
  end if;
  return v_result;
end $$;
revoke all on function public.gs_dashboard_overview(date) from public, anon;
grant execute on function public.gs_dashboard_overview(date) to authenticated;
