-- Read-only canonical ledger allocation preview for a single order.
-- This does not certify global Standing Cash/Pending Payment balances.
create or replace function public.gs_financial_order_method_allocation(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
 a jsonb;
 v_order_total numeric;
 v_credit numeric;
 v_debit numeric;
 v_cash numeric;
 v_card numeric;
 v_online numeric;
 v_credit_account numeric;
 v_owner numeric;
 v_refund numeric;
 v_reversal numeric;
 v_unclassified bigint;
 v_credit_entries bigint;
 v_debit_entries bigint;
 v_source_duplicates bigint;
 v_external_unmatched bigint;
 v_unlinked_cash bigint;
 v_failed bigint;
 v_remaining numeric;
 v_checks jsonb;
begin
 if (select auth.uid()) is null or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
   raise exception 'Payments Management viewing permission required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id<=0 then
   raise exception 'Valid order ID required' using errcode='22023';
 end if;
 -- Existing integrity audit enforces the same permission and validates order identity.
 a := public.gs_financial_order_integrity_audit(p_order_id);
 if a->>'order_id' <> p_order_id::text or jsonb_typeof(a->'checks') <> 'object' then
   raise exception 'Unexpected order audit' using errcode='22023';
 end if;
 v_order_total := (a->>'order_items_total_iqd')::numeric;
 select coalesce(sum(amount_iqd) filter(where direction='credit'),0),
        coalesce(sum(amount_iqd) filter(where direction='debit'),0),
        coalesce(sum(amount_iqd) filter(where direction='credit' and entry_type='cash'),0),
        coalesce(sum(amount_iqd) filter(where direction='credit' and entry_type='card'),0),
        coalesce(sum(amount_iqd) filter(where direction='credit' and entry_type='online'),0),
        coalesce(sum(amount_iqd) filter(where direction='credit' and entry_type='credit'),0),
        coalesce(sum(amount_iqd) filter(where direction='credit' and entry_type='owner_waiver'),0),
        coalesce(sum(amount_iqd) filter(where direction='debit' and entry_type='refund'),0),
        coalesce(sum(amount_iqd) filter(where direction='debit' and entry_type='reversal'),0),
        count(*) filter(where direction='credit' and entry_type not in ('cash','card','online','credit','owner_waiver')),
        count(*) filter(where direction='credit'),
        count(*) filter(where direction='debit')
 into v_credit,v_debit,v_cash,v_card,v_online,v_credit_account,v_owner,v_refund,v_reversal,
      v_unclassified,v_credit_entries,v_debit_entries
 from public.gs_unified_payment_ledger where order_id=p_order_id;
 select count(*) into v_source_duplicates from (
   select source_system,source_reference from public.gs_unified_payment_ledger
   where order_id=p_order_id group by source_system,source_reference having count(*)>1
 ) d;
 v_external_unmatched := (a->>'unmatched_verified_external_count')::bigint;
 v_unlinked_cash := (a->>'unlinked_legacy_cash_count')::bigint;
 select count(*) into v_failed from jsonb_each(a->'checks') c where c.value <> 'true'::jsonb;
 v_remaining := v_order_total-v_credit+v_debit;
 v_checks := jsonb_build_object(
  'order_audit_passes',v_failed=0,
  'no_unlinked_legacy_cash',v_unlinked_cash=0,
  'external_references_matched',v_external_unmatched=0,
  'no_duplicate_ledger_source',v_source_duplicates=0,
  'all_credits_classified',v_unclassified=0,
  'credits_match_method_breakdown',v_credit=v_cash+v_card+v_online+v_credit_account+v_owner,
  'debits_match_reversal_breakdown',v_debit=v_refund+v_reversal,
  'no_negative_net_settlement',v_credit>=v_debit,
  'no_negative_remaining',v_remaining>=0,
  'nonnegative_order_total',v_order_total>=0
 );
 return jsonb_build_object(
  'order_id',p_order_id,'order_total_iqd',v_order_total,
  'cash_credits_iqd',v_cash,'card_credits_iqd',v_card,'online_credits_iqd',v_online,
  'credit_account_credits_iqd',v_credit_account,'owner_waiver_credits_iqd',v_owner,
  'refund_debits_iqd',v_refund,'reversal_debits_iqd',v_reversal,
  'total_credits_iqd',v_credit,'total_debits_iqd',v_debit,
  'net_ledger_settlement_iqd',v_credit-v_debit,
  'candidate_remaining_iqd',v_remaining,
  'credit_entry_count',v_credit_entries,'debit_entry_count',v_debit_entries,
  'duplicate_source_count',v_source_duplicates,'unlinked_cash_count',v_unlinked_cash,
  'unmatched_external_count',v_external_unmatched,'failed_audit_checks',v_failed,
  'checks',v_checks,'verified_complete',false,'settlement_confirmed',false,
  'candidate_only',true,'generated_at',now(),
  'warning','Ledger-only method allocation preview. Candidate remaining amount is NOT a certified unpaid balance. Prepaid packages, credit account debit confirmation, item allocations, source completeness and full pagination remain unverified.'
 );
end; $$;
revoke all on function public.gs_financial_order_method_allocation(bigint) from public,anon;
grant execute on function public.gs_financial_order_method_allocation(bigint) to authenticated;
