-- Finance-only safety upgrade: authoritative identity diagnostics, no settlement posting.
-- Numeric cafe orders and UUID motel requests have no proven native relationship.
-- This migration intentionally does NOT relax gs_motel_bridge_no_unverified_legacy_link.
create or replace function public.gs_financial_cross_domain_preflight(p_order_id bigint, p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_bridge public.gs_motel_finance_source_bridge%rowtype;
 v_order_total numeric; v_conflicts bigint;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Finance and motel viewing permission required' using errcode='42501'; end if;
 if p_order_id is null or p_order_id<=0 or p_invoice_id is null then
 raise exception 'Valid numeric order ID and invoice UUID required' using errcode='22023'; end if;
 select * into v_order from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Cafe order not found' using errcode='P0002'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Motel invoice not found' using errcode='P0002'; end if;
 select * into v_bridge from public.gs_motel_finance_source_bridge where finance_invoice_id=p_invoice_id;
 select coalesce(sum(line_total_iqd),0) into v_order_total from public.gs_order_items where order_id=p_order_id;
 select count(*) into v_conflicts from public.gs_motel_finance_source_bridge
 where legacy_order_id=p_order_id and finance_invoice_id<>p_invoice_id;
 return jsonb_build_object(
 'order_id',p_order_id,'invoice_id',p_invoice_id,'order_is_motel',v_order.is_motel,
 'order_total_iqd',v_order_total,'invoice_total_iqd',v_invoice.total_iqd,
 'source_bridge_exists',v_bridge.id is not null,
 'bridge_invoice_matches',case when v_bridge.id is null then false else
 (v_bridge.finance_invoice_id=p_invoice_id and v_bridge.amount_iqd=v_invoice.total_iqd
 and v_bridge.guest_session_id=v_invoice.guest_session_id
 and v_bridge.room_id=v_invoice.room_id) end,
 'other_invoice_crosswalk_conflicts',v_conflicts,
 'amounts_equal',v_order_total=v_invoice.total_iqd,
 'explicit_crosswalk_exists',false,'identity_verified',false,
 'prepaid_allocation_confirmed',false,'credit_debit_confirmed',false,
 'verified_complete',false,'certified_unpaid_iqd',null,'generated_at',now(),
 'warning','Matching amounts, motel flags or bridge registration are not identity proof. Explicit independent source evidence is required before mapping or settlement.');
end $$;
revoke all on function public.gs_financial_cross_domain_preflight(bigint,uuid) from public,anon;
grant execute on function public.gs_financial_cross_domain_preflight(bigint,uuid) to authenticated;

-- Check the credit account journal idempotency constraints before any future debit writer.
-- This function cannot debit an account or mark an invoice paid.
create or replace function public.gs_financial_credit_debit_preflight(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_request public.gs_motel_credit_verification_requests%rowtype;
 v_intent public.gs_motel_food_payment_intent_drafts%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_links bigint; v_account uuid; v_account_status text; v_customer_status text;
 v_existing bigint; v_total numeric; v_other_charges bigint;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Payments, credit and motel viewing permissions required' using errcode='42501'; end if;
 if p_request_id is null then raise exception 'Request UUID required' using errcode='22023'; end if;
 select * into v_request from public.gs_motel_credit_verification_requests where id=p_request_id;
 if not found then raise exception 'Verification request not found' using errcode='P0002'; end if;
 select * into v_intent from public.gs_motel_food_payment_intent_drafts where id=v_request.intent_id;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=v_intent.finance_invoice_id;
 select count(*),(array_agg(l.account_id))[1] into v_links,v_account from public.gs_credit_account_registry_links l
 where l.registry_id=v_request.registry_id and l.link_status='verified';
 select a.account_status,c.verification_status into v_account_status,v_customer_status
 from public.gs_credit_accounts a join public.gs_credit_customers c on c.id=a.customer_id where a.id=v_account;
 select count(*),coalesce(sum(j.delta_outstanding_iqd),0) into v_existing,v_total
 from public.gs_credit_account_journal j where j.source_request_id=p_request_id and j.event_kind='charge';
 select count(*) into v_other_charges from public.gs_credit_account_journal j
 where j.source_request_id=p_request_id and j.event_kind<>'charge';
 return jsonb_build_object(
 'request_id',p_request_id,'invoice_id',v_invoice.id,'intent_id',v_intent.id,
 'request_status',v_request.status,'intent_method',v_intent.method,
 'request_amount_iqd',v_request.amount_iqd,'intent_amount_iqd',v_intent.amount_iqd,
 'invoice_amount_iqd',v_invoice.total_iqd,'invoice_payment_status',v_invoice.payment_status,
 'verified_registry_link_count',v_links,'account_id',v_account,
 'account_status',v_account_status,'customer_verification_status',v_customer_status,
 'existing_charge_count',v_existing,'existing_charge_amount_iqd',v_total,
 'other_journal_events_on_request',v_other_charges,
 'amounts_consistent',v_request.amount_iqd=v_intent.amount_iqd,
 'request_pending',v_request.status='pending',
 'single_verified_account',v_links=1,
 'eligible_for_debit',false,'authorized_debit_confirmed',false,
 'verified_complete',false,'generated_at',now(),
 'warning','Read-only diagnostics. Verified registry linkage and existing journal charges do not authorize a new debit or prove settlement.');
end $$;
revoke all on function public.gs_financial_credit_debit_preflight(uuid) from public,anon;
grant execute on function public.gs_financial_credit_debit_preflight(uuid) to authenticated;
