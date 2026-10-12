-- Upgrade 484: cash collection reporting ONLY, not revenue, profit or total settlements.
-- Legacy table-order cash and UUID motel-food cash remain separate ledgers.
create or replace function public.gs_dashboard_cash_collections_today()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_start timestamptz := ((now() at time zone 'Asia/Baghdad')::date::timestamp at time zone 'Asia/Baghdad');
  v_end timestamptz := (((now() at time zone 'Asia/Baghdad')::date + 1)::timestamp at time zone 'Asia/Baghdad');
  v_table_total numeric; v_table_count bigint;
  v_motel_total numeric; v_motel_count bigint;
  v_result jsonb := jsonb_build_object('as_of',now(),'timezone','Asia/Baghdad','scope','cash_collections_only','reconciled',false);
begin
  if auth.uid() is null or not coalesce(public.gs_can_access('dashboard','can_view'),false) then
    raise exception 'Dashboard access denied' using errcode='42501';
  end if;
  if coalesce(public.gs_can_access('table_orders','can_view'),false) and
     (coalesce(public.gs_can_access('invoices_payments','can_view'),false) or
      coalesce(public.gs_can_access('payments_management','can_view'),false)) then
    select coalesce(sum(amount_iqd),0),count(*) into v_table_total,v_table_count
      from public.gs_cash_payments where collected_at >= v_start and collected_at < v_end;
    v_result := v_result || jsonb_build_object('table_cash_iqd',v_table_total,'table_cash_receipts',v_table_count);
  end if;
  if coalesce(public.gs_can_access('motel_orders','can_view'),false) and
     (coalesce(public.gs_can_access('invoices_payments','can_view'),false) or
      coalesce(public.gs_can_access('payments_management','can_view'),false)) then
    select coalesce(sum(amount_iqd),0),count(*) into v_motel_total,v_motel_count
      from public.gs_motel_food_cash_settlements where settled_at >= v_start and settled_at < v_end;
    v_result := v_result || jsonb_build_object('motel_food_cash_iqd',v_motel_total,'motel_food_cash_receipts',v_motel_count);
  end if;
  return v_result;
end; $$;
revoke all on function public.gs_dashboard_cash_collections_today() from public,anon;
grant execute on function public.gs_dashboard_cash_collections_today() to authenticated;
