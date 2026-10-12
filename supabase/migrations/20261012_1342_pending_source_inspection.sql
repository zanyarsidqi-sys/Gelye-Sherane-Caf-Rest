-- Upgrade 1342: source-classified read-only pending payment inspection.
-- The motel finance invoice is a posted source document, NOT a proven due amount.
-- Online order linkage and prepaid/provider settlement are not yet certified.
create or replace function public.gs_financial_pending_source_inspection()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_invoices jsonb;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_view'),false)
   or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
   or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
   raise exception 'Payments, motel and finance viewing permissions required' using errcode='42501';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'source','motel_finance_invoice',
   'finance_invoice_id',s.id::text,
   'guest_session_id',s.guest_session_id::text,
   'invoice_total_iqd',s.total_iqd,
   'payment_status',s.payment_status,
   'posted_at',s.posted_at,
   'collection_eligible',false
 ) order by s.posted_at desc,s.id), '[]'::jsonb) into v_invoices
 from (select id,guest_session_id,total_iqd,payment_status,posted_at
       from public.gs_motel_food_finance_invoices
       where payment_status='unpaid' order by posted_at desc,id limit 200) s;
 return jsonb_build_object(
   'verified_complete',false,'collection_enabled',false,
   'online_classified',false,'motel_invoices',v_invoices,
   'scope','posted_unpaid_status_motel_invoice_sources_only',
   'warning','Invoice total is not remaining due; prepaid packages, external settlement, refunds and online source identity are not reconciled');
end; $$;
revoke all on function public.gs_financial_pending_source_inspection() from public,anon;
grant execute on function public.gs_financial_pending_source_inspection() to authenticated;
