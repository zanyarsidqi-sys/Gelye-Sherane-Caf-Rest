-- Atomic motel prepaid allocation + dedicated journal, in one RPC transaction.
-- Does NOT change invoice payment_status or populate the cafe-order unified ledger.
-- If journal posting fails, PostgreSQL rolls back allocation in the same statement.
create or replace function public.gs_financial_allocate_and_journal_verified_prepaid(p_receipt_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_allocation jsonb; v_journal jsonb; v_allocation_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Invoice payment permission required' using errcode='42501'; end if;
 if p_receipt_id is null then raise exception 'Verified receipt required' using errcode='22023'; end if;
 v_allocation := public.gs_financial_allocate_verified_motel_prepaid(p_receipt_id);
 if v_allocation is null or jsonb_typeof(v_allocation)<>'object'
 or v_allocation->>'allocation_id' is null or (v_allocation->>'amount_iqd')::bigint <= 0
 or v_allocation->>'invoice_settled' <> 'false'
 or v_allocation->>'unified_ledger_posted' <> 'false'
 or v_allocation->>'dashboard_certified' <> 'false'
 then raise exception 'Prepaid allocation response invalid'; end if;
 v_allocation_id := (v_allocation->>'allocation_id')::uuid;
 v_journal := public.gs_financial_post_motel_prepaid_settlement(v_allocation_id);
 if v_journal is null or jsonb_typeof(v_journal)<>'object'
 or v_journal->>'journal_id' is null
 or v_journal->>'invoice_id' is distinct from v_allocation->>'invoice_id'
 or v_journal->>'amount_iqd' is distinct from v_allocation->>'amount_iqd'
 or v_journal->>'invoice_status_updated' <> 'false'
 or v_journal->>'unified_ledger_posted' <> 'false'
 or v_journal->>'dashboard_certified' <> 'false'
 then raise exception 'Prepaid journal reconciliation failed'; end if;
 return jsonb_build_object('allocation_id',v_allocation_id,
  'journal_id',v_journal->>'journal_id',
  'invoice_id',v_allocation->>'invoice_id',
  'amount_iqd',(v_allocation->>'amount_iqd')::bigint,
  'already_allocated',(v_allocation->>'already_allocated')::boolean,
  'already_posted',(v_journal->>'already_posted')::boolean,
  'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_financial_allocate_and_journal_verified_prepaid(uuid) from public,anon;
grant execute on function public.gs_financial_allocate_and_journal_verified_prepaid(uuid) to authenticated;
