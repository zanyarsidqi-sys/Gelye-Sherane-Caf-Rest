-- Upgrade 392: read-only compatibility gate. No financial postings.
-- The legacy unified ledger requires gs_orders(bigint); motel invoices are UUID-based.
-- Never coerce IDs or create dummy gs_orders to force compatibility.
create or replace function public.gs_staff_motel_payment_ledger_compatibility(p_intent_id uuid)
returns table(intent_id uuid, compatibility_status text, source_invoice_id uuid,
 source_order_model text, destination_order_model text, payment_method text,
 amount_iqd bigint, reason text)
language plpgsql stable security definer set search_path = '' as $$
declare v public.gs_motel_food_payment_intent_drafts%rowtype;
 v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_check record;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v from public.gs_motel_food_payment_intent_drafts d where d.id=p_intent_id;
 if not found then raise exception 'Payment draft not found'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices f where f.id=v.finance_invoice_id;
 if not found then raise exception 'Finance invoice missing'; end if;
 select * into v_check from public.gs_staff_check_motel_food_payment_draft(v.id);
 return query select v.id,
  case when v_check.check_status='ready_for_future_integration'
    then 'mapping_required' else 'blocked' end::text,
  v.finance_invoice_id,
  'motel_food_finance_invoices.id (uuid)'::text,
  'gs_unified_payment_ledger.order_id -> gs_orders.id (bigint)'::text,
  v.method,v.amount_iqd,
  case when v_check.check_status='ready_for_future_integration' then
   'No safe invoice-to-gs_orders mapping exists. Do not post to the shared ledger until a verified source mapping and settlement writer are implemented.'
  else 'Payment draft is not eligible: '||coalesce(v_check.details,'') end::text;
end; $$;
revoke all on function public.gs_staff_motel_payment_ledger_compatibility(uuid) from public,anon;
grant execute on function public.gs_staff_motel_payment_ledger_compatibility(uuid) to authenticated;
