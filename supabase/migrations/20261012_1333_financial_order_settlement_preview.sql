-- Upgrade 1333: read-only per-order unified-ledger settlement diagnostic.
-- Does not post payments, certify unpaid balances, or conflate legacy cash with ledger credits.
create or replace function public.gs_financial_order_settlement_preview(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_is_motel boolean;
  v_visit_id bigint;
  v_visit_status text;
  v_credits bigint;
  v_debits bigint;
  v_entries bigint;
begin
  if (select auth.uid()) is null or
     not coalesce(public.gs_can_access('payments_management','can_view'),false) then
    raise exception 'Payments Management viewing permission required' using errcode='42501';
  end if;
  if p_order_id is null or p_order_id <= 0 then
    raise exception 'Valid order ID required' using errcode='22023';
  end if;
  select o.is_motel,o.table_visit_id into v_is_motel,v_visit_id
    from public.gs_orders o where o.id=p_order_id;
  if not found then
    raise exception 'Order not found' using errcode='P0002';
  end if;
  if v_visit_id is null then
    v_visit_status := 'unbound';
  else
    select v.status into v_visit_status from public.gs_table_visits v where v.id=v_visit_id;
    v_visit_status := coalesce(v_visit_status,'missing');
  end if;
  select coalesce(sum(l.amount_iqd) filter(where l.direction='credit'),0),
         coalesce(sum(l.amount_iqd) filter(where l.direction='debit'),0),
         count(*) into v_credits,v_debits,v_entries
    from public.gs_unified_payment_ledger l where l.order_id=p_order_id;
  return jsonb_build_object(
    'order_id',p_order_id,'is_motel',v_is_motel,
    'visit_status',v_visit_status,'ledger_credits_iqd',v_credits,
    'ledger_debits_iqd',v_debits,'ledger_entries',v_entries,
    'settlement_confirmed',false,
    'warning','Diagnostic ledger only: legacy cash and external/prepaid settlements are not fully reconciled');
end; $$;
revoke all on function public.gs_financial_order_settlement_preview(bigint) from public,anon;
grant execute on function public.gs_financial_order_settlement_preview(bigint) to authenticated;
