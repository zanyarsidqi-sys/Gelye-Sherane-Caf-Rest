-- Upgrade: read-only per-order integrity audit. No settlement certification or posting.
-- Each check is computed from persisted identities, not a static checklist.
create or replace function public.gs_financial_order_integrity_audit(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  o public.gs_orders%rowtype;
  v_total numeric;
  v_cash numeric;
  v_ledger_credits numeric;
  v_ledger_debits numeric;
  v_invalid_links bigint;
  v_unlinked_cash bigint;
  v_bad_reversals bigint;
  v_duplicate_reversals bigint;
  v_external_pending bigint;
  v_external_verified bigint;
  v_unmatched_external bigint;
  v_ledger_count bigint;
  v_visit_status text;
  v_visit_table bigint;
  v_visit_closed timestamptz;
  v_overpaid boolean;
  v_checks jsonb;
begin
  if (select auth.uid()) is null or
     not coalesce(public.gs_can_access('payments_management','can_view'), false) then
    raise exception 'Payments Management viewing permission required' using errcode='42501';
  end if;
  if p_order_id is null or p_order_id <= 0 then
    raise exception 'Valid order ID required' using errcode='22023';
  end if;
  select * into o from public.gs_orders where id=p_order_id;
  if not found then raise exception 'Order not found' using errcode='P0002'; end if;
  select coalesce(sum(i.line_total_iqd),0) into v_total from public.gs_order_items i where i.order_id=p_order_id;
  select coalesce(sum(c.amount_iqd),0),count(*) filter(where x.legacy_cash_id is null)
    into v_cash,v_unlinked_cash
    from public.gs_cash_payments c left join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
    where c.order_id=p_order_id;
  select count(*) into v_invalid_links from public.gs_cash_payments c
    join public.gs_cash_ledger_reconciliation_links x on x.legacy_cash_id=c.id
    left join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
    where c.order_id=p_order_id and (l.id is null or l.order_id<>c.order_id
      or l.entry_type<>'cash' or l.direction<>'credit' or l.amount_iqd<>c.amount_iqd
      or l.source_system<>'legacy_cash');
  select coalesce(sum(l.amount_iqd) filter(where l.direction='credit'),0),
         coalesce(sum(l.amount_iqd) filter(where l.direction='debit'),0),count(*)
    into v_ledger_credits,v_ledger_debits,v_ledger_count
    from public.gs_unified_payment_ledger l where l.order_id=p_order_id;
  select count(*) into v_bad_reversals from public.gs_unified_payment_ledger l
    left join public.gs_unified_payment_ledger orig on orig.id=l.original_entry_id
    where l.order_id=p_order_id and l.direction='debit' and
      (orig.id is null or orig.order_id<>l.order_id or orig.direction<>'credit' or
       l.amount_iqd>orig.amount_iqd or orig.posted_at>l.posted_at);
  select count(*) into v_duplicate_reversals from (
    select l.original_entry_id from public.gs_unified_payment_ledger l
    where l.order_id=p_order_id and l.direction='debit'
    group by l.original_entry_id having sum(l.amount_iqd) >
      coalesce((select orig.amount_iqd from public.gs_unified_payment_ledger orig
                where orig.id=l.original_entry_id),0)
  ) duplicates;
  select count(*) filter(where e.verification_status<>'verified'),
         count(*) filter(where e.verification_status='verified')
    into v_external_pending,v_external_verified
    from public.gs_external_payment_evidence e where e.order_id=p_order_id;
  -- Evidence is not a settlement. A verified external reference still requires
  -- a separately validated canonical allocation; never add it to ledger credits.
  select count(*) into v_unmatched_external from public.gs_external_payment_evidence e
    where e.order_id=p_order_id and e.verification_status='verified'
      and not exists (select 1 from public.gs_unified_payment_ledger l
        where l.order_id=e.order_id and l.source_reference=e.external_reference
          and l.amount_iqd=e.amount_iqd and l.direction='credit');
  if o.table_visit_id is not null then
    select v.status,v.table_id,v.closed_at into v_visit_status,v_visit_table,v_visit_closed
      from public.gs_table_visits v where v.id=o.table_visit_id;
  end if;
  v_overpaid := (v_ledger_credits-v_ledger_debits)>v_total;
  v_checks:=jsonb_build_object(
    'order_exists',true,
    'order_has_items',v_total>0,
    'cash_crosswalk_valid',v_invalid_links=0,
    'all_legacy_cash_crosswalked',v_unlinked_cash=0,
    'reversal_originals_valid',v_bad_reversals=0,
    'reversals_not_overallocated',v_duplicate_reversals=0,
    'no_unverified_external_evidence',v_external_pending=0,
    'verified_external_refs_have_ledger_match',v_unmatched_external=0,
    'ledger_not_over_order_total',not v_overpaid,
    'visit_reference_resolves',o.table_visit_id is null or v_visit_status is not null,
    'motel_not_bound_to_table_visit',not o.is_motel or o.table_visit_id is null,
    'cancelled_order_has_no_net_ledger_credit',o.status<>'cancelled' or v_ledger_credits=v_ledger_debits
  );
  return jsonb_build_object(
    'order_id',p_order_id,'is_motel',o.is_motel,'order_status',o.status,
    'table_visit_id',o.table_visit_id,'visit_status',v_visit_status,
    'visit_table_id',v_visit_table,'visit_closed_at',v_visit_closed,
    'order_items_total_iqd',v_total,'legacy_cash_iqd',v_cash,
    'ledger_credits_iqd',v_ledger_credits,'ledger_debits_iqd',v_ledger_debits,
    'ledger_entry_count',v_ledger_count,'unlinked_legacy_cash_count',v_unlinked_cash,
    'invalid_cash_crosswalk_count',v_invalid_links,'invalid_reversal_count',v_bad_reversals,
    'overallocated_reversal_count',v_duplicate_reversals,
    'unverified_external_count',v_external_pending,'verified_external_count',v_external_verified,
    'unmatched_verified_external_count',v_unmatched_external,
    'checks',v_checks,'verified_complete',false,'settlement_confirmed',false,
    'warning','Read-only integrity audit, NOT a complete balance or payment certification. Prepaid, credit, mixed and partial allocations, source disjointness, and full source pagination still require trusted reconciliation.',
    'generated_at',now());
end; $$;
revoke all on function public.gs_financial_order_integrity_audit(bigint) from public, anon;
grant execute on function public.gs_financial_order_integrity_audit(bigint) to authenticated;
