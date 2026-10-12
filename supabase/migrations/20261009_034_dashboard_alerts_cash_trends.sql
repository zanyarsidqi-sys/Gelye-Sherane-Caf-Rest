-- Apply after 033 and inventory migration 026.
-- Scoped inventory alerts and cash trend, with no direct table grants.
create or replace function public.gs_dashboard_overview(p_day date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_day date := coalesce(p_day, (now() at time zone 'Asia/Baghdad')::date);
  v_orders boolean; v_motel boolean; v_kitchen boolean; v_cash boolean; v_tables boolean;
  v_inventory boolean; v_finance boolean; v_result jsonb := jsonb_build_object('day',v_day);
  v_count bigint; v_total bigint; v_paid bigint;
begin
  if auth.uid() is null or not public.gs_can_access('dashboard') then
    raise exception 'Dashboard access denied';
  end if;
  v_orders := public.gs_can_access('table_orders');
  v_motel := public.gs_can_access('motel_orders');
  v_kitchen := public.gs_can_access('kitchen');
  v_tables := public.gs_can_access('tables');
  v_inventory := public.gs_can_access('products_inventory');
  v_cash := public.gs_can_access('payments_management') or public.gs_can_access('invoices_payments');
  v_finance := v_cash or public.gs_can_access('revenue');

  if v_orders or v_motel then
    select count(*) into v_count from public.gs_orders o
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('orders',v_count);
    select count(*) into v_count from public.gs_orders o
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
      and o.status not in ('served','cancelled')
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('active_orders',v_count);
    select count(*) into v_count from public.gs_orders o
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
      and o.status<>'cancelled' and o.tourism_mode
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    v_result := v_result || jsonb_build_object('tourism_orders',v_count);
  end if;
  if v_finance then
    select coalesce(sum(i.line_total_iqd),0) into v_total
    from public.gs_orders o join public.gs_order_items i on i.order_id=o.id
    where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
      and o.status<>'cancelled'
      and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
    -- Only show scoped order value when both finance and the respective order permission exist.
    if v_orders or v_motel then
      v_result := v_result || jsonb_build_object('order_value_iqd',v_total);
    end if;
  end if;
  if v_motel then
    select count(*) into v_count from public.gs_orders o
      where o.is_motel and (o.created_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('motel_orders',v_count);
  end if;
  if v_kitchen then
    select count(*) into v_count from public.gs_orders o
      where o.status in ('new','preparing','ready')
      and (o.created_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('kitchen_queue',v_count);
  end if;
  if v_cash then
    select coalesce(sum(p.amount_iqd),0) into v_paid from public.gs_cash_payments p
      where (p.collected_at at time zone 'Asia/Baghdad')::date=v_day;
    v_result := v_result || jsonb_build_object('cash_collected_iqd',v_paid);
    if v_orders or v_motel then
      select coalesce(sum(greatest(coalesce(t.total,0)-coalesce(c.paid,0),0)),0)
        into v_total from public.gs_orders o
      left join lateral (select sum(i.line_total_iqd) total from public.gs_order_items i where i.order_id=o.id) t on true
      left join lateral (select sum(p.amount_iqd) paid from public.gs_cash_payments p where p.order_id=o.id) c on true
      where (o.created_at at time zone 'Asia/Baghdad')::date=v_day
        and o.status<>'cancelled'
        and ((not o.is_motel and v_orders) or (o.is_motel and v_motel));
      v_result := v_result || jsonb_build_object('outstanding_iqd',v_total);
    end if;
  end if;
  if v_tables then
    select count(*), count(*) filter (where occupied) into v_total,v_count
      from public.gs_cafe_tables;
    v_result := v_result || jsonb_build_object('total_tables',v_total,'occupied_tables',v_count);
    select coalesce(sum(guests) filter (where occupied),0) into v_count from public.gs_cafe_tables;
    v_result := v_result || jsonb_build_object('seated_guests',v_count);
  end if;
  if v_inventory then
    select count(*) filter (where coalesce(s.quantity,0) <= coalesce(s.minimum_quantity,5)),
           count(*) filter (where coalesce(s.quantity,0) = 0)
    into v_total, v_count
    from public.gs_menu_products p
    left join public.gs_inventory_stock s on s.product_id=p.id
    where p.is_active=true;
    v_result := v_result || jsonb_build_object('low_stock_count',v_total,'out_of_stock_count',v_count);
  end if;
  return v_result;
end $$;
revoke all on function public.gs_dashboard_overview(date) from public, anon;
grant execute on function public.gs_dashboard_overview(date) to authenticated;

create or replace function public.gs_dashboard_week(p_day date default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_day date := coalesce(p_day,(now() at time zone 'Asia/Baghdad')::date);
 v_orders boolean; v_motel boolean; v_cash boolean; v_result jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('dashboard') then
   raise exception 'Dashboard access denied';
 end if;
 v_orders := public.gs_can_access('table_orders');
 v_motel := public.gs_can_access('motel_orders');
 v_cash := public.gs_can_access('payments_management') or public.gs_can_access('invoices_payments');
 if not v_orders and not v_motel then return '[]'::jsonb; end if;
 select coalesce(jsonb_agg(jsonb_build_object('day', d.day::text,'orders',
    (select count(*) from public.gs_orders o
     where (o.created_at at time zone 'Asia/Baghdad')::date=d.day
       and ((not o.is_motel and v_orders) or (o.is_motel and v_motel))),
    'cash_iqd', case when v_cash then
      (select coalesce(sum(p.amount_iqd),0) from public.gs_cash_payments p
       join public.gs_orders o on o.id=p.order_id
       where (p.collected_at at time zone 'Asia/Baghdad')::date=d.day
       and ((not o.is_motel and v_orders) or (o.is_motel and v_motel)))
      else null end)
   order by d.day),'[]'::jsonb) into v_result
 from generate_series(v_day - 6,v_day,interval '1 day') as d(day);
 return v_result;
end $$;
revoke all on function public.gs_dashboard_week(date) from public, anon;
grant execute on function public.gs_dashboard_week(date) to authenticated;
