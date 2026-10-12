-- Source-identity diagnostic, not a posting engine or settlement confirmation.
-- A matching external reference is a candidate only; never count evidence and ledger twice.
create or replace function public.gs_financial_order_source_identity(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 v_cross_order bigint; v_same_order bigint; v_unmatched bigint;
 v_cash_unlinked bigint; v_motel boolean; v_visit text;
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
 into v_motel,v_visit
 from public.gs_orders o left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=p_order_id;
 if not found then raise exception 'Order not found' using errcode='P0002'; end if;
 -- External references are unique per method, but a ledger reference is only a
 -- candidate for deduplication. Count cross-order matches separately.
 select count(*) filter(where l.id is not null and l.order_id<>e.order_id),
        count(*) filter(where l.id is not null and l.order_id=e.order_id),
        count(*) filter(where l.id is null)
 into v_cross_order,v_same_order,v_unmatched
 from public.gs_external_payment_evidence e
 left join public.gs_unified_payment_ledger l
   on l.source_reference=e.external_reference
  and l.entry_type=e.method
  and l.direction='credit'
 where e.order_id=p_order_id and e.verification_status='verified';
 select count(*) into v_cash_unlinked
 from public.gs_cash_payments c
 left join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 where c.order_id=p_order_id and x.legacy_cash_id is null;
 return jsonb_build_object(
  'order_id',p_order_id,'is_motel',v_motel,'visit_status',v_visit,
  'external_same_order_reference_candidates',v_same_order,
  'external_cross_order_reference_conflicts',v_cross_order,
  'external_without_ledger_reference',v_unmatched,
  'legacy_cash_without_crosswalk',v_cash_unlinked,
  'source_identity_complete',false,'verified_complete',false,
  'warning','Reference matches are candidates only, not verified allocations. Cash crosswalks, external settlement finality, visit status and motel prepayments require independent reconciliation.');
end $$;
revoke all on function public.gs_financial_order_source_identity(bigint) from public,anon;
grant execute on function public.gs_financial_order_source_identity(bigint) to authenticated;
