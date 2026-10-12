-- Upgrade 488: permission-scoped seven-day cash collection trend; never revenue or reconciled accounting.
create or replace function public.gs_dashboard_cash_collections_week()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_today date := (now() at time zone 'Asia/Baghdad')::date;
  v_date date;
  v_start timestamptz;
  v_end timestamptz;
  v_table numeric;
  v_table_count bigint;
  v_motel numeric;
  v_motel_count bigint;
  v_table_allowed boolean;
  v_motel_allowed boolean;
  v_days jsonb := '[]'::jsonb;
  v_item jsonb;
begin
  if auth.uid() is null or not coalesce(public.gs_can_access('dashboard','can_view'),false) then
    raise exception 'Dashboard access denied' using errcode='42501';
  end if;
  v_table_allowed := coalesce(public.gs_can_access('table_orders','can_view'),false) and
    (coalesce(public.gs_can_access('invoices_payments','can_view'),false) or
     coalesce(public.gs_can_access('payments_management','can_view'),false));
  v_motel_allowed := coalesce(public.gs_can_access('motel_orders','can_view'),false) and
    (coalesce(public.gs_can_access('invoices_payments','can_view'),false) or
     coalesce(public.gs_can_access('payments_management','can_view'),false));
  for i in 0..6 loop
    v_date := v_today - (6-i);
    v_start := (v_date::timestamp at time zone 'Asia/Baghdad');
    v_end := ((v_date+1)::timestamp at time zone 'Asia/Baghdad');
    v_item := jsonb_build_object('business_date',to_char(v_date,'YYYY-MM-DD'),
      'table_cash_iqd',null,'table_cash_receipts',null,
      'motel_food_cash_iqd',null,'motel_food_cash_receipts',null);
    if v_table_allowed then
      select coalesce(sum(amount_iqd),0), count(*) into v_table,v_table_count
        from public.gs_cash_payments where collected_at >= v_start and collected_at < v_end;
      v_item := v_item || jsonb_build_object('table_cash_iqd',v_table,'table_cash_receipts',v_table_count);
    end if;
    if v_motel_allowed then
      select coalesce(sum(amount_iqd),0), count(*) into v_motel,v_motel_count
        from public.gs_motel_food_cash_settlements where settled_at >= v_start and settled_at < v_end;
      v_item := v_item || jsonb_build_object('motel_food_cash_iqd',v_motel,'motel_food_cash_receipts',v_motel_count);
    end if;
    v_days := v_days || jsonb_build_array(v_item);
  end loop;
  return jsonb_build_object('as_of',now(),'timezone','Asia/Baghdad',
    'scope','cash_collections_only','reconciled',false,'days',v_days);
end; $$;
revoke all on function public.gs_dashboard_cash_collections_week() from public,anon;
grant execute on function public.gs_dashboard_cash_collections_week() to authenticated;
