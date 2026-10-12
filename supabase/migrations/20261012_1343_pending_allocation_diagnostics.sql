-- Read-only motel invoice allocation diagnostics. Never returns a collectible balance.
-- Based on UUID finance invoices and their separate cash settlement, intent,
-- review and allocation-plan tables; no unproven gs_orders mapping.
create or replace function public.gs_financial_pending_allocation_diagnostics()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_rows jsonb;
begin
 if auth.uid() is null
    or not coalesce(public.gs_can_access('payments_management','can_view'),false)
    or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
   raise exception 'Finance and motel viewing permissions required' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'finance_invoice_id', i.id::text,
   'invoice_total_iqd',i.total_iqd,
   'invoice_status',i.payment_status,
   'bridge_count',(select count(*) from public.gs_motel_finance_source_bridge b where b.finance_invoice_id=i.id),
   'draft_intent_count',(select count(*) from public.gs_motel_food_payment_intent_drafts d where d.finance_invoice_id=i.id),
   'review_plan_count',(select count(*) from public.gs_motel_food_payment_allocation_plans p where p.finance_invoice_id=i.id),
   'confirmed_cash_settlement_count',(select count(*) from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=i.id),
   'confirmed_cash_settlement_iqd',(select coalesce(sum(c.amount_iqd),0) from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=i.id),
   'collection_eligible',false
 ) order by i.posted_at desc,i.id),'[]'::jsonb) into v_rows
 from (select id,total_iqd,payment_status,posted_at
       from public.gs_motel_food_finance_invoices
       order by posted_at desc,id limit 200) i;
 return jsonb_build_object('verified_complete',false,'collection_enabled',false,
   'online_classified',false,'motel_allocation_diagnostics',v_rows,
   'warning','Confirmed cash settlement is only one channel. Draft intents and review plans are not payments; prepaid packages, provider settlement and refunds are not reconciled.');
end; $$;
revoke all on function public.gs_financial_pending_allocation_diagnostics() from public,anon;
grant execute on function public.gs_financial_pending_allocation_diagnostics() to authenticated;
