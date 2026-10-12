-- Upgrade: guarded Standing Cash collection; never claim all-method certification.
-- This is intentionally CASH-ONLY. Other methods require separate confirmed provider flows.
create or replace function public.gs_standing_cash_collect_cash(
 p_order_id bigint, p_amount_iqd bigint, p_reference uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_visit bigint; v_status text; v_motel boolean; v_receipt bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_create')
    or not public.gs_can_access('payments_management','can_view') then
   raise exception 'Payment collection not authorized';
 end if;
 if p_order_id is null or p_order_id <= 0 or p_amount_iqd is null
    or p_amount_iqd <= 0 or p_reference is null then
   raise exception 'Invalid payment request';
 end if;
 -- Lock the order before examining eligibility; payment writers must share this lock.
 select o.table_visit_id, o.status, o.is_motel
 into v_visit, v_status, v_motel
 from public.gs_orders o where o.id=p_order_id for update;
 if not found or v_motel or v_status='cancelled' or v_visit is null then
   raise exception 'Not an eligible café table order';
 end if;
 if not exists(select 1 from public.gs_table_visits v
   where v.id=v_visit and v.status='active' and v.closed_at is null) then
   raise exception 'Table visit is no longer active';
 end if;
 -- Fail closed on other channels or unresolved settlement sources. Never infer
 -- that unmatched legacy and unified ledger entries are independent receipts.
 if exists(select 1 from public.gs_unified_payment_ledger l
   where l.order_id=p_order_id)
 or exists(select 1 from public.gs_external_payment_evidence e
   where e.order_id=p_order_id)
 or exists(select 1 from public.gs_owner_guest_offers g
   where g.order_id=p_order_id)
 or exists(select 1 from public.gs_table_bill_transfer_request_items i
   join public.gs_order_items oi on oi.id=i.order_item_id
   where oi.order_id=p_order_id)
 then raise exception 'Mixed or disputed settlement requires finance review'; end if;
 -- Existing function enforces outstanding amount, idempotency, row locking,
 -- staff permission, and writes the canonical legacy cash receipt.
 select public.gs_record_cash_payment(p_order_id,p_amount_iqd,p_reference)
 into v_receipt;
 return v_receipt;
end; $$;
revoke all on function public.gs_standing_cash_collect_cash(bigint,bigint,uuid) from public,anon;
grant execute on function public.gs_standing_cash_collect_cash(bigint,bigint,uuid) to authenticated;

create or replace function public.gs_standing_cash_active_orders()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('payments_management','can_view')
   or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Standing Cash list not authorized'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'order_id',s.id,'table_id',s.table_id,'visit_id',s.visit_id,
   'order_total_iqd',s.total,'cash_paid_iqd',s.paid,
   'cash_only_remaining_iqd',greatest(0,s.total-s.paid),
   'cash_collection_eligible',s.eligible) order by s.id), '[]'::jsonb)
 into v_result from (
  select o.id,v.table_id,v.id as visit_id,
   (select coalesce(sum(i.line_total_iqd),0)::bigint from public.gs_order_items i where i.order_id=o.id) as total,
   (select coalesce(sum(p.amount_iqd),0)::bigint from public.gs_cash_payments p where p.order_id=o.id) as paid,
   not exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id)
   and not exists(select 1 from public.gs_external_payment_evidence e where e.order_id=o.id)
   and not exists(select 1 from public.gs_owner_guest_offers g where g.order_id=o.id)
   and not exists(select 1 from public.gs_table_bill_transfer_request_items t
      join public.gs_order_items i on i.id=t.order_item_id where i.order_id=o.id)
   as eligible
  from public.gs_orders o join public.gs_table_visits v on v.id=o.table_visit_id
  where v.status='active' and v.closed_at is null and not o.is_motel
    and o.status <> 'cancelled'
  order by o.id desc limit 200
 ) s where s.total>s.paid;
 return jsonb_build_object('orders',v_result,'complete',false,
   'scope','active_visits_cash_only_sample','limit',200);
end; $$;
revoke all on function public.gs_standing_cash_active_orders() from public,anon;
grant execute on function public.gs_standing_cash_active_orders() to authenticated;
