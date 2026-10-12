-- Read-only reference amount and motel finance mapping diagnostics.
-- Does not infer payment finality from a matching reference or mark invoices paid.
create or replace function public.gs_financial_order_amount_motel_safety(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_motel boolean; v_visit text; v_amount_mismatch bigint; v_cross_order bigint;
 v_unmatched bigint; v_verified bigint; v_bridge_count bigint; v_bridge_amount bigint;
 v_motel_unmapped bigint; v_motel_conflicting bigint;
begin
 if (select auth.uid()) is null or
    not coalesce(public.gs_can_access('payments_management','can_view'),false) then
   raise exception 'Payments Management viewing permission required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id <= 0 then
   raise exception 'Valid order ID required' using errcode='22023';
 end if;
 select o.is_motel, case when o.table_visit_id is null then 'unbound'
    else coalesce(v.status,'missing') end
 into v_motel,v_visit from public.gs_orders o
 left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=p_order_id;
 if not found then raise exception 'Order not found' using errcode='P0002'; end if;
 -- Count each external evidence row once, even when multiple ledger candidates exist.
 select count(*) filter(where exists (
    select 1 from public.gs_unified_payment_ledger l
    where l.source_reference=e.external_reference and l.entry_type=e.method
      and l.direction='credit' and l.order_id=p_order_id
      and l.amount_iqd<>e.amount_iqd)),
  count(*) filter(where exists (
    select 1 from public.gs_unified_payment_ledger l
    where l.source_reference=e.external_reference and l.entry_type=e.method
      and l.direction='credit' and l.order_id<>p_order_id)),
  count(*) filter(where not exists (
    select 1 from public.gs_unified_payment_ledger l
    where l.source_reference=e.external_reference and l.entry_type=e.method
      and l.direction='credit')),
  count(*)
 into v_amount_mismatch,v_cross_order,v_unmatched,v_verified
 from public.gs_external_payment_evidence e
 where e.order_id=p_order_id and e.verification_status='verified';
 -- The motel bridge explicitly forbids claiming a legacy order mapping until
 -- separately reviewed. Never merge UUID finance invoices into legacy orders.
 select count(*),coalesce(sum(b.amount_iqd),0)
 into v_bridge_count,v_bridge_amount
 from public.gs_motel_finance_source_bridge b
 where b.legacy_order_id=p_order_id;
 select count(*) filter(where b.id is null),
        count(*) filter(where b.id is not null and
          (b.amount_iqd<>f.total_iqd or b.guest_session_id<>f.guest_session_id
           or b.room_id<>f.room_id or b.source_fingerprint<>f.source_fingerprint))
 into v_motel_unmapped,v_motel_conflicting
 from public.gs_motel_food_finance_invoices f
 left join public.gs_motel_finance_source_bridge b on b.finance_invoice_id=f.id;
 return jsonb_build_object(
  'order_id',p_order_id,'is_motel',v_motel,'visit_status',v_visit,
  'verified_external_evidence_count',v_verified,
  'external_reference_amount_mismatch_count',v_amount_mismatch,
  'external_reference_cross_order_conflict_count',v_cross_order,
  'external_reference_without_ledger_count',v_unmatched,
  'legacy_order_motel_bridge_count',v_bridge_count,
  'legacy_order_motel_bridge_amount_iqd',v_bridge_amount,
  'motel_finance_invoices_without_bridge_count',v_motel_unmapped,
  'motel_finance_bridge_source_conflict_count',v_motel_conflicting,
  'verified_complete',false,'settlement_confirmed',false,
  'warning','Amount/reference matches are diagnostic only. Motel finance invoice UUIDs and legacy order IDs must not be merged without approved source mapping; prepaid package settlement is not proven.');
end $$;
revoke all on function public.gs_financial_order_amount_motel_safety(bigint) from public,anon;
grant execute on function public.gs_financial_order_amount_motel_safety(bigint) to authenticated;
