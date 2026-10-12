-- Upgrade: cross-domain settlement safety gate for Standing Cash / Pending Payment.
-- The existing source bridge explicitly prohibits legacy_order_id mapping.
-- No fabricated numeric order identity, prepaid credit, or debit confirmation.
create or replace function public.gs_financial_motel_settlement_identity_gate(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.gs_motel_food_finance_invoices%rowtype;
 v_bridge public.gs_motel_finance_source_bridge%rowtype;
 v_cash_count bigint; v_cash_amount numeric; v_cash_conflicts bigint;
 v_intent_count bigint; v_credit_count bigint; v_electronic_count bigint;
 v_credit_journal_count bigint; v_credit_amount numeric;
 v_request_count bigint; v_crosswalk_count bigint;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Payments, Motel and Credit viewing permissions required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice UUID required' using errcode='22023'; end if;
 select * into v from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select * into v_bridge from public.gs_motel_finance_source_bridge
 where finance_invoice_id=p_invoice_id;
 select count(*),coalesce(sum(amount_iqd),0),
 count(*) filter(where amount_iqd<>v.total_iqd)
 into v_cash_count,v_cash_amount,v_cash_conflicts
 from public.gs_motel_food_cash_settlements where finance_invoice_id=p_invoice_id;
 select count(*),count(*) filter(where method='credit'),
 count(*) filter(where method='electronic')
 into v_intent_count,v_credit_count,v_electronic_count
 from public.gs_motel_food_payment_intent_drafts where finance_invoice_id=p_invoice_id;
 select count(j.id),coalesce(sum(j.delta_outstanding_iqd),0),count(distinct q.id)
 into v_credit_journal_count,v_credit_amount,v_request_count
 from public.gs_motel_food_payment_intent_drafts d
 join public.gs_motel_credit_verification_requests q on q.intent_id=d.id
 left join public.gs_credit_account_journal j on j.source_request_id=q.id and j.event_kind='charge'
 where d.finance_invoice_id=p_invoice_id and d.method='credit';
 -- No safe cafe-order crosswalk exists: the bridge has an enforced NULL legacy ID.
 select count(*) into v_crosswalk_count from public.gs_motel_finance_source_bridge
 where finance_invoice_id=p_invoice_id and legacy_order_id is not null;
 return jsonb_build_object(
 'invoice_id',p_invoice_id,'invoice_total_iqd',v.total_iqd,
 'invoice_payment_status',v.payment_status,'bridge_registered',v_bridge.id is not null,
 'bridge_id',v_bridge.id,'bridge_amount_matches',case when v_bridge.id is null then null else
 (v_bridge.amount_iqd=v.total_iqd and v_bridge.guest_session_id=v.guest_session_id
 and v_bridge.room_id=v.room_id) end,
 'legacy_crosswalk_count',v_crosswalk_count,
 'cash_settlement_count',v_cash_count,'cash_settlement_amount_iqd',v_cash_amount,
 'cash_amount_conflicts',v_cash_conflicts,
 'draft_intent_count',v_intent_count,'credit_draft_count',v_credit_count,
 'electronic_draft_count',v_electronic_count,
 'credit_verification_request_count',v_request_count,
 'credit_journal_charge_count',v_credit_journal_count,
 'credit_journal_charge_amount_iqd',v_credit_amount,
 'cash_status_consistent',((v.payment_status='paid_cash' and v_cash_count=1
 and v_cash_amount=v.total_iqd and v_cash_conflicts=0)
 or (v.payment_status='unpaid' and v_cash_count=0)),
 'prepaid_allocation_confirmed',false,'credit_debit_confirmed',false,
 'numeric_order_mapping_verified',false,'all_sources_exhaustively_reconciled',false,
 'verified_complete',false,'certified_unpaid_iqd',null,
 'generated_at',now(),
 'warning','Credit journal evidence is not proof of authorized debit; payment drafts are not settlement. Numeric cafe orders and UUID motel sources remain unmapped.');
end $$;
revoke all on function public.gs_financial_motel_settlement_identity_gate(uuid) from public,anon;
grant execute on function public.gs_financial_motel_settlement_identity_gate(uuid) to authenticated;
