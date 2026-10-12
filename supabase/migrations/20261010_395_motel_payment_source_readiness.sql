-- Upgrade 395: validate UUID motel invoice/payment draft against registered source bridge.
-- This is a read-only integration gate; NEVER fabricate a gs_orders bigint ID.
-- No payment posting, credit deduction or settlement is authorized here.
create or replace function public.gs_staff_check_motel_payment_source(p_intent_id uuid)
returns table(intent_id uuid, finance_invoice_id uuid, bridge_id uuid,
 source_status text, amount_iqd bigint, legacy_order_id bigint, details text)
language plpgsql security definer set search_path = '' as $$
declare v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_b public.gs_motel_finance_source_bridge%rowtype;
 v_check record; v_source record;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id;
 if not found then raise exception 'Payment draft not found'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id;
 if not found then raise exception 'Finance invoice missing'; end if;
 select * into v_check from public.gs_staff_check_motel_food_payment_draft(v_d.id);
 select * into v_source from public.gs_staff_check_motel_food_finance_invoice(v_f.id);
 select * into v_b from public.gs_motel_finance_source_bridge where finance_invoice_id=v_f.id;
 return query select v_d.id,v_f.id,v_b.id,
 case
  when v_check.check_status is distinct from 'ready_for_future_integration' then 'blocked_draft'
  when v_source.check_status is distinct from 'matched' then 'blocked_reconciliation'
  when v_b.id is null then 'missing_bridge'
  when v_b.guest_session_id is distinct from v_f.guest_session_id
    or v_b.room_id is distinct from v_f.room_id
    or v_b.amount_iqd is distinct from v_f.total_iqd
    or v_b.source_fingerprint is distinct from v_f.source_fingerprint then 'bridge_mismatch'
  when v_b.legacy_order_id is not null or v_b.mapping_status <> 'unmapped' then 'unverified_legacy_mapping'
  else 'source_verified_ledger_mapping_pending' end::text,
 v_d.amount_iqd,v_b.legacy_order_id,
 case when v_b.id is null then 'Register the finance source before continuing.'
 when v_b.legacy_order_id is not null then 'Legacy mapping is not certified; payment posting prohibited.'
 else 'UUID source checks completed; legacy gs_orders(bigint) mapping and settlement writer are not implemented. No payment may be posted.' end::text;
end; $$;
revoke all on function public.gs_staff_check_motel_payment_source(uuid) from public,anon;
grant execute on function public.gs_staff_check_motel_payment_source(uuid) to authenticated;
