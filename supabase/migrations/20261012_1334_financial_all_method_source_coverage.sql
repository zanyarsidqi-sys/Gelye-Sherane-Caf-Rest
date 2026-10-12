-- Read-only canonical-source coverage inspection. No posting or settlement certification.
-- Cash/ledger crosswalks are only trusted when order, amount, type and source agree.
create or replace function public.gs_financial_order_all_method_coverage(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_order public.gs_orders%rowtype;
 v_total numeric; v_cash numeric; v_linked_cash numeric; v_unlinked_cash numeric;
 v_non_cash numeric; v_reversals numeric; v_verified_external numeric;
 v_cash_count bigint; v_linked_count bigint; v_ledger_count bigint;
 v_external_count bigint; v_bad_links bigint; v_visit_status text;
begin
 if (select auth.uid()) is null or
    not coalesce(public.gs_can_access('payments_management','can_view'),false) then
   raise exception 'Payments Management viewing permission required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id <= 0 then
   raise exception 'Valid order ID required' using errcode='22023';
 end if;
 select * into v_order from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Order not found' using errcode='P0002'; end if;
 select coalesce(sum(i.line_total_iqd),0) into v_total
 from public.gs_order_items i where i.order_id=p_order_id;
 select coalesce(sum(c.amount_iqd),0),count(*) into v_cash,v_cash_count
 from public.gs_cash_payments c where c.order_id=p_order_id;
 select coalesce(sum(c.amount_iqd),0),count(*) into v_linked_cash,v_linked_count
 from public.gs_cash_payments c
 join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
 where c.order_id=p_order_id and l.order_id=c.order_id
   and l.entry_type='cash' and l.direction='credit'
   and l.amount_iqd=c.amount_iqd and l.source_system='legacy_cash';
 v_unlinked_cash := v_cash-v_linked_cash;
 select coalesce(sum(l.amount_iqd) filter(where l.direction='credit' and l.entry_type<>'cash'),0),
        coalesce(sum(l.amount_iqd) filter(where l.direction='debit'),0),count(*)
 into v_non_cash,v_reversals,v_ledger_count
 from public.gs_unified_payment_ledger l where l.order_id=p_order_id;
 select coalesce(sum(e.amount_iqd) filter(where e.verification_status='verified'),0),count(*)
 into v_verified_external,v_external_count
 from public.gs_external_payment_evidence e where e.order_id=p_order_id;
 select count(*) into v_bad_links
 from public.gs_cash_payments c
 join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 left join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
 where c.order_id=p_order_id and (l.id is null or l.order_id<>c.order_id
 or l.entry_type<>'cash' or l.direction<>'credit'
 or l.amount_iqd<>c.amount_iqd or l.source_system<>'legacy_cash');
 if v_order.table_visit_id is null then v_visit_status:='unbound';
 else
  select v.status into v_visit_status from public.gs_table_visits v
   where v.id=v_order.table_visit_id;
  v_visit_status:=coalesce(v_visit_status,'missing');
 end if;
 return jsonb_build_object(
  'order_id',p_order_id,'is_motel',v_order.is_motel,'visit_status',v_visit_status,
  'order_items_total_iqd',v_total,'legacy_cash_iqd',v_cash,
  'crosswalk_matched_cash_iqd',v_linked_cash,
  'unlinked_legacy_cash_iqd',v_unlinked_cash,
  'unified_non_cash_credits_iqd',v_non_cash,
  'unified_reversals_iqd',v_reversals,
  'verified_external_evidence_iqd',v_verified_external,
  'cash_receipt_count',v_cash_count,'matched_cash_count',v_linked_count,
  'ledger_entry_count',v_ledger_count,'external_evidence_count',v_external_count,
  'invalid_cash_crosswalk_count',v_bad_links,
  'settlement_confirmed',false,'verified_complete',false,
  'warning','Source coverage only. External evidence may overlap ledger entries; prepaid motel, waivers, reversals, transfers and posting finality require canonical allocations. Never sum these categories into a paid or unpaid balance.');
end $$;
revoke all on function public.gs_financial_order_all_method_coverage(bigint) from public,anon;
grant execute on function public.gs_financial_order_all_method_coverage(bigint) to authenticated;
