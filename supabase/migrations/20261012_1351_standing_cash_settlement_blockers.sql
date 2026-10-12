-- Upgrade 1351: inspect Standing Cash cross-channel settlement blockers.
-- Read-only: do not authorize collection based on this result.
create or replace function public.gs_standing_cash_settlement_blockers(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_order_exists boolean; v_ledger bigint; v_external bigint;
 v_offers bigint; v_transfers bigint; v_receipt_anomalies jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('payments_management','can_view')
    or not public.gs_can_access('invoices_payments','can_view')
    or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Settlement inspection not authorized';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order identifier'; end if;
 select exists(select 1 from public.gs_orders o where o.id=p_order_id and not o.is_motel)
 into v_order_exists;
 if not v_order_exists then raise exception 'Eligible table order not found' using errcode='P0002'; end if;
 select count(*) into v_ledger from public.gs_unified_payment_ledger l where l.order_id=p_order_id;
 select count(*) into v_external from public.gs_external_payment_evidence e where e.order_id=p_order_id;
 select count(*) into v_offers from public.gs_owner_guest_offers g where g.order_id=p_order_id;
 select count(*) into v_transfers from public.gs_table_bill_transfer_request_items t
 join public.gs_order_items i on i.id=t.order_item_id where i.order_id=p_order_id;
 v_receipt_anomalies := public.gs_standing_cash_receipt_integrity(p_order_id);
 return jsonb_build_object('order_id',p_order_id,
  'unified_ledger_records',v_ledger,'external_evidence_records',v_external,
  'owner_offer_records',v_offers,'transfer_item_records',v_transfers,
  'cash_receipt_anomalies',v_receipt_anomalies->'requires_finance_review',
  'requires_finance_review',v_ledger>0 or v_external>0 or v_offers>0 or v_transfers>0
      or coalesce((v_receipt_anomalies->>'requires_finance_review')::boolean,true),
  'collection_authorized',false,'settlement_confirmed',false,
  'scope','read_only_cross_channel_blocker_diagnostics',
  'warning','This is not a complete settlement ledger. Never derive collectible balance from this diagnostic.');
end $$;
revoke all on function public.gs_standing_cash_settlement_blockers(bigint) from public,anon;
grant execute on function public.gs_standing_cash_settlement_blockers(bigint) to authenticated;
