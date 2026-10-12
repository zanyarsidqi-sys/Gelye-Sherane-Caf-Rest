-- Read-only invoice and credit journal reconciliation grounded in existing UUID schemas.
-- No ledger posting, balance certification, or payment authorization.
create or replace function public.gs_financial_motel_invoice_integrity(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare f public.gs_motel_food_finance_invoices%rowtype;
 v_lines bigint; v_sum numeric; v_duplicates bigint; v_missing bigint;
 v_wrong bigint; v_negative bigint; v_drafts bigint; v_status text;
begin
 if (select auth.uid()) is null or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Payments and Motel viewing permissions required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice UUID required' using errcode='22023'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select count(*),coalesce(sum(l.amount_iqd),0),
  count(*) filter(where l.amount_iqd<0),
  count(*) filter(where r.id is null or r.source_order_id is distinct from l.source_order_id
    or r.amount_iqd is distinct from l.amount_iqd)
 into v_lines,v_sum,v_negative,v_wrong
 from public.gs_motel_food_finance_invoice_lines l
 left join public.gs_motel_food_invoice_register_lines r on r.id=l.source_register_line_id
 where l.finance_invoice_id=f.id;
 select count(*) into v_duplicates from (
  select source_order_id from public.gs_motel_food_finance_invoice_lines
  where finance_invoice_id=f.id group by source_order_id having count(*)>1
 ) d;
 select count(*) into v_missing from public.gs_motel_food_invoice_register_lines r
 where r.invoice_id=f.food_invoice_id and not exists (
  select 1 from public.gs_motel_food_finance_invoice_lines l
  where l.source_register_line_id=r.id and l.finance_invoice_id=f.id);
 select count(*) into v_drafts from public.gs_motel_food_payment_intent_drafts d
 where d.finance_invoice_id=f.id and d.status='draft';
 v_status:=case when v_lines=f.source_count and v_sum=f.total_iqd
 and v_negative=0 and v_wrong=0 and v_duplicates=0 and v_missing=0
 then 'invoice_source_consistent' else 'invoice_source_mismatch' end;
 return jsonb_build_object('invoice_id',f.id,'food_invoice_id',f.food_invoice_id,
 'guest_session_id',f.guest_session_id,'room_id',f.room_id,
 'invoice_total_iqd',f.total_iqd,'line_total_iqd',v_sum,'line_count',v_lines,
 'expected_line_count',f.source_count,'negative_line_count',v_negative,
 'mismatched_register_line_count',v_wrong,'duplicate_source_order_count',v_duplicates,
 'missing_register_line_count',v_missing,'draft_payment_intent_count',v_drafts,
 'invoice_source_status',v_status,'prepaid_certified_iqd',null,
 'settled_iqd',null,'outstanding_iqd',null,'verified_complete',false,
 'generated_at',now(), 'warning','Invoice source integrity does not establish payment, prepaid allocation or settlement.');
end $$;
revoke all on function public.gs_financial_motel_invoice_integrity(uuid) from public,anon;
grant execute on function public.gs_financial_motel_invoice_integrity(uuid) to authenticated;

create or replace function public.gs_financial_credit_journal_integrity(p_account_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.gs_credit_accounts%rowtype; v_count bigint; v_delta numeric;
 v_last numeric; v_invalid bigint; v_duplicate bigint; v_unlinked bigint;
begin
 if (select auth.uid()) is null or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('credit_management','can_view'),false) then
  raise exception 'Payments and Credit viewing permissions required' using errcode='42501'; end if;
 if p_account_id is null then raise exception 'Account UUID required' using errcode='22023'; end if;
 select * into a from public.gs_credit_accounts where id=p_account_id;
 if not found then raise exception 'Credit account not found' using errcode='P0002'; end if;
 select count(*),coalesce(sum(j.delta_outstanding_iqd),0),
  count(*) filter(where (j.event_kind='charge' and j.delta_outstanding_iqd<=0)
    or (j.event_kind='repayment' and j.delta_outstanding_iqd>=0)),
  count(*) filter(where j.event_kind='charge' and j.source_request_id is null)
 into v_count,v_delta,v_invalid,v_unlinked
 from public.gs_credit_account_journal j where j.account_id=a.id;
 select j.outstanding_after_iqd into v_last from public.gs_credit_account_journal j
 where j.account_id=a.id order by j.created_at desc,j.id desc limit 1;
 select count(*) into v_duplicate from (
  select external_idempotency_key from public.gs_credit_account_journal
  where account_id=a.id group by external_idempotency_key having count(*)>1
 ) d;
 return jsonb_build_object('account_id',a.id,'account_status',a.account_status,
 'journal_entry_count',v_count,'journal_delta_iqd',v_delta,
 'recorded_outstanding_iqd',a.outstanding_iqd,'last_journal_outstanding_iqd',v_last,
 'invalid_direction_count',v_invalid,'unlinked_charge_count',v_unlinked,
 'duplicate_idempotency_count',v_duplicate,
 'journal_matches_recorded_balance',v_count>0 and v_last=a.outstanding_iqd,
 'credit_debit_authoritatively_confirmed',false,
 'verified_complete',false,'generated_at',now(),
 'warning','Journal consistency does not establish an authorized customer debit or linkage to a specific cafe/motel order.');
end $$;
revoke all on function public.gs_financial_credit_journal_integrity(uuid) from public,anon;
grant execute on function public.gs_financial_credit_journal_integrity(uuid) to authenticated;
