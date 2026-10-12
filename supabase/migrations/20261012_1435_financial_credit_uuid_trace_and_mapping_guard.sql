-- Correct unsafe cross-domain identity assumption: motel source_order_id is UUID,
-- referencing gs_motel_guest_food_requests; gs_orders.id is bigint.
-- Never infer an order match from a text cast or a coincidental representation.
create or replace function public.gs_financial_order_motel_uuid_links(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Payments and Motel viewing permissions required' using errcode='42501'; end if;
 if p_order_id is null or p_order_id<=0 then
 raise exception 'Positive order ID required' using errcode='22023'; end if;
 if not exists(select 1 from public.gs_orders where id=p_order_id) then
 raise exception 'Order not found' using errcode='P0002'; end if;
 return jsonb_build_object('order_id',p_order_id,'motel_source_line_count',null,
 'distinct_invoice_count',null,'linked_source_total_iqd',null,
 'invoice_links','[]'::jsonb,'identity_mapping_verified',false,
 'mapping_status','incompatible_source_identity_domains',
 'source_order_id_type','uuid','cafe_order_id_type','bigint',
 'prepaid_certified_iqd',null,'credit_debit_confirmed',false,
 'settled_iqd',null,'outstanding_iqd',null,'verified_complete',false,
 'generated_at',now(), 'warning',
 'Motel invoice source_order_id references a UUID guest food request, not a bigint cafe order. An explicit verified crosswalk is required.');
end $$;
revoke all on function public.gs_financial_order_motel_uuid_links(bigint) from public,anon;
grant execute on function public.gs_financial_order_motel_uuid_links(bigint) to authenticated;

-- UUID-native trace of credit journal events to their verification request,
-- draft intent and motel finance invoice. Trace does not confirm customer consent,
-- authorization, prepaid settlement, or ledger posting.
create or replace function public.gs_financial_credit_journal_invoice_trace(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_intents bigint; v_requests bigint; v_charges bigint; v_total numeric;
 v_unlinked bigint; v_mismatched bigint; v_duplicates bigint; v_events jsonb;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Payments, Motel and Credit viewing permissions required' using errcode='42501'; end if;
 if p_invoice_id is null then raise exception 'Invoice UUID required' using errcode='22023'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id;
 if not found then raise exception 'Invoice not found' using errcode='P0002'; end if;
 select count(*) into v_intents from public.gs_motel_food_payment_intent_drafts
 where finance_invoice_id=p_invoice_id and method='credit';
 select count(*) into v_requests from public.gs_motel_credit_verification_requests q
 join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
 where d.finance_invoice_id=p_invoice_id;
 select count(*),coalesce(sum(j.delta_outstanding_iqd),0),
 count(*) filter(where j.event_kind<>'charge' or j.delta_outstanding_iqd<=0
 or j.delta_outstanding_iqd is distinct from q.amount_iqd
 or d.amount_iqd is distinct from q.amount_iqd
 or q.status<>'pending'),
 count(*) filter(where l.registry_id is null or l.account_id<>j.account_id
 or l.link_status<>'verified'),
 count(*)-count(distinct j.external_idempotency_key)
 into v_charges,v_total,v_mismatched,v_unlinked,v_duplicates
 from public.gs_credit_account_journal j
 join public.gs_motel_credit_verification_requests q on q.id=j.source_request_id
 join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
 left join public.gs_credit_account_registry_links l on l.registry_id=q.registry_id
 where d.finance_invoice_id=p_invoice_id and j.event_kind='charge';
 select coalesce(jsonb_agg(jsonb_build_object(
 'journal_id',x.id,'request_id',x.source_request_id,
 'account_id',x.account_id,'event_kind',x.event_kind,
 'delta_outstanding_iqd',x.delta_outstanding_iqd,
 'outstanding_after_iqd',x.outstanding_after_iqd,
 'created_at',x.created_at) order by x.created_at,x.id),'[]'::jsonb)
 into v_events from (
 select j.id,j.source_request_id,j.account_id,j.event_kind,
 j.delta_outstanding_iqd,j.outstanding_after_iqd,j.created_at
 from public.gs_credit_account_journal j
 join public.gs_motel_credit_verification_requests q on q.id=j.source_request_id
 join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
 where d.finance_invoice_id=p_invoice_id order by j.created_at,j.id limit 100
 ) x;
 return jsonb_build_object('invoice_id',p_invoice_id,
 'credit_intent_count',v_intents,'verification_request_count',v_requests,
 'linked_charge_count',v_charges,'linked_charge_delta_iqd',v_total,
 'mismatched_charge_count',v_mismatched,'unverified_account_link_count',v_unlinked,
 'duplicate_idempotency_count',v_duplicates,'events_preview',v_events,
 'events_preview_limit',100,'events_preview_exhaustive',
 (select count(*)<=100 from public.gs_credit_account_journal j
 join public.gs_motel_credit_verification_requests q on q.id=j.source_request_id
 join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
 where d.finance_invoice_id=p_invoice_id),
 'credit_debit_authoritatively_confirmed',false,
 'prepaid_certified_iqd',null,'settled_iqd',null,
 'outstanding_iqd',null,'verified_complete',false,'generated_at',now(),
 'warning','Journal event linkage is evidence only; no customer debit or motel prepaid settlement is certified.');
end $$;
revoke all on function public.gs_financial_credit_journal_invoice_trace(uuid) from public,anon;
grant execute on function public.gs_financial_credit_journal_invoice_trace(uuid) to authenticated;
