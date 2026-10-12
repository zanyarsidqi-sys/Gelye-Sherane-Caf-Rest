-- Read-only settlement source reconciliation; never authorizes posting or totals.
create or replace function public.gs_financial_order_source_reconciliation(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
 a jsonb; m jsonb; v_cash bigint; v_linked bigint; v_unlinked bigint;
 v_external_verified bigint; v_external_matched bigint; v_external_unmatched bigint;
 v_credit_verified bigint; v_credit_matched bigint; v_credit_unmatched bigint;
 v_cross_order bigint; v_duplicate_external bigint; v_partial boolean;
 v_mixed boolean; v_prepaid bigint; v_item_alloc bigint; v_item_alloc_bad bigint;
 v_credit_unbacked bigint; v_total numeric; v_net numeric; v_checks jsonb;
begin
 if (select auth.uid()) is null or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
  raise exception 'Payments Management viewing permission required' using errcode='42501'; end if;
 if p_order_id is null or p_order_id<=0 then raise exception 'Invalid order ID' using errcode='22023'; end if;
 a:=public.gs_financial_order_integrity_audit(p_order_id);
 m:=public.gs_financial_order_method_allocation(p_order_id);
 if (a->>'order_id')::bigint<>p_order_id or (m->>'order_id')::bigint<>p_order_id then
  raise exception 'Source identity mismatch' using errcode='22023'; end if;
 select coalesce(sum(c.amount_iqd),0)::bigint,
        coalesce(sum(c.amount_iqd) filter(where x.legacy_cash_id is not null),0)::bigint,
        count(*) filter(where x.legacy_cash_id is null)
 into v_cash,v_linked,v_unlinked
 from public.gs_cash_payments c left join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
 where c.order_id=p_order_id;
 select count(*) filter(where e.verification_status='verified'),
        count(*) filter(where e.verification_status='verified' and exists
          (select 1 from public.gs_unified_payment_ledger l where l.order_id=e.order_id
           and l.source_reference=e.external_reference and l.amount_iqd=e.amount_iqd
           and l.direction='credit' and l.entry_type in ('card','online','credit'))),
        count(*) filter(where e.verification_status='verified' and not exists
          (select 1 from public.gs_unified_payment_ledger l where l.order_id=e.order_id
           and l.source_reference=e.external_reference and l.amount_iqd=e.amount_iqd
           and l.direction='credit' and l.entry_type in ('card','online','credit'))),
        count(*) filter(where e.method='credit' and e.verification_status='verified'),
        count(*) filter(where e.method='credit' and e.verification_status='verified' and exists
          (select 1 from public.gs_unified_payment_ledger l where l.order_id=e.order_id
           and l.source_reference=e.external_reference and l.amount_iqd=e.amount_iqd
           and l.direction='credit' and l.entry_type='credit')),
        count(*) filter(where e.method='credit' and e.verification_status='verified' and not exists
          (select 1 from public.gs_unified_payment_ledger l where l.order_id=e.order_id
           and l.source_reference=e.external_reference and l.amount_iqd=e.amount_iqd
           and l.direction='credit' and l.entry_type='credit'))
 into v_external_verified,v_external_matched,v_external_unmatched,v_credit_verified,v_credit_matched,v_credit_unmatched
 from public.gs_external_payment_evidence e where e.order_id=p_order_id;
 select count(*) into v_cross_order from public.gs_unified_payment_ledger l
 join public.gs_external_payment_evidence e on e.external_reference=l.source_reference
 where l.order_id=p_order_id and e.order_id<>p_order_id;
 select count(*) into v_duplicate_external from (
 select e.external_reference from public.gs_external_payment_evidence e
 where e.order_id=p_order_id group by e.external_reference having count(*)>1
 ) d;
 select coalesce(sum(i.amount_iqd),0)::bigint,
        count(*) filter(where i.order_id<>l.order_id or i.order_id<>oi.order_id or i.amount_iqd>l.amount_iqd)
 into v_item_alloc,v_item_alloc_bad from public.gs_item_payment_allocations i
 join public.gs_unified_payment_ledger l on l.id=i.payment_ledger_entry_id
 join public.gs_order_items oi on oi.id=i.order_item_id where i.order_id=p_order_id;
 select count(*) into v_credit_unbacked from public.gs_unified_payment_ledger l
 where l.order_id=p_order_id and l.direction='credit' and l.entry_type='credit'
 and not exists (select 1 from public.gs_external_payment_evidence e
 where e.order_id=l.order_id and e.method='credit' and e.verification_status='verified'
 and e.external_reference=l.source_reference and e.amount_iqd=l.amount_iqd);
 v_total:=(m->>'order_total_iqd')::numeric; v_net:=(m->>'net_ledger_settlement_iqd')::numeric;
 v_partial:=v_net>0 and v_net<v_total;
 v_mixed:=(select count(distinct l.entry_type)>1 from public.gs_unified_payment_ledger l
 where l.order_id=p_order_id and l.direction='credit');
 -- A motel prepaid amount is not assumed to be settled merely because the order is motel-linked.
 v_prepaid:=0;
 v_checks:=jsonb_build_object(
 'cash_receipts_all_crosswalked',v_unlinked=0,
 'cash_amount_crosswalk_matches',v_cash=v_linked,
 'external_evidence_matched',v_external_unmatched=0,
 'credit_evidence_matched',v_credit_unmatched=0,
 'credit_ledger_backed_by_evidence',v_credit_unbacked=0,
 'no_cross_order_external_reference',v_cross_order=0,
 'no_duplicate_external_reference',v_duplicate_external=0,
 'item_allocations_bind_to_order',v_item_alloc_bad=0,
 'item_allocations_not_above_ledger',v_item_alloc<=greatest(v_net,0),
 'order_audit_checks_pass',not exists(select 1 from jsonb_each(a->'checks') x where x.value<>'true'::jsonb),
 'method_allocation_checks_pass',not exists(select 1 from jsonb_each(m->'checks') x where x.value<>'true'::jsonb),
 'motel_prepayments_authoritatively_bound',false,
 'credit_account_debit_authoritatively_confirmed',false,
 'all_payment_sources_exhaustively_enumerated',false
 );
 return jsonb_build_object('order_id',p_order_id,'legacy_cash_iqd',v_cash,
 'crosswalked_cash_iqd',v_linked,'unlinked_cash_count',v_unlinked,
 'verified_external_count',v_external_verified,'matched_external_count',v_external_matched,
 'unmatched_external_count',v_external_unmatched,'verified_credit_count',v_credit_verified,
 'matched_credit_count',v_credit_matched,'unmatched_credit_count',v_credit_unmatched,
 'unbacked_credit_ledger_count',v_credit_unbacked,'cross_order_reference_count',v_cross_order,
 'duplicate_external_reference_count',v_duplicate_external,
 'item_allocated_iqd',v_item_alloc,'invalid_item_allocation_count',v_item_alloc_bad,
 'partial_settlement_observed',v_partial,'mixed_methods_observed',v_mixed,
 'motel_prepayments_certified_iqd',null,'order_total_iqd',v_total,
 'net_ledger_settlement_iqd',v_net,'checks',v_checks,
 'verified_complete',false,'settlement_confirmed',false,'generated_at',now(),
 'warning','Source reconciliation is read-only. No prepaid package or credit account debit can be certified from these records alone.');
end $$;
revoke all on function public.gs_financial_order_source_reconciliation(bigint) from public,anon;
grant execute on function public.gs_financial_order_source_reconciliation(bigint) to authenticated;
