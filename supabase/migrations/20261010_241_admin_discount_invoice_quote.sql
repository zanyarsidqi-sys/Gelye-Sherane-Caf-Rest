-- Upgrade 241: Read-only Admin-approved discount invoice quotation.
-- IMPORTANT: does NOT alter financial ledger, invoice or printer payloads.
-- Fail closed on payment evidence and stale approval drafts.
create or replace function public.gs_admin_bill_discount_invoice_quote(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_draft public.gs_admin_bill_discount_drafts%rowtype;
 v_total bigint;
 v_has_item_discount boolean;
 v_order_status text;
 v_payment_table text;
 v_has_payment boolean;
begin
 if auth.uid() is null or not exists
   (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid()) then
   raise exception 'Admin authorization required';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order'; end if;
 select status::text into v_order_status from public.gs_orders where id=p_order_id;
 if not found or v_order_status in ('cancelled','paid','settled','closed','completed') then
   raise exception 'Order not eligible for discount invoice quote';
 end if;
 select * into v_draft from public.gs_admin_bill_discount_drafts
 where order_id=p_order_id and status='draft' order by approved_at desc,id desc limit 1;
 if not found then raise exception 'No approved discount draft for order'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint,
   coalesce(bool_or(discount_per_unit_iqd>0),false)
 into v_total,v_has_item_discount from public.gs_order_items where order_id=p_order_id;
 if v_total<=0 or v_total<>v_draft.source_total_iqd then
   raise exception 'Order total changed after approval; new approval required';
 end if;
 if v_has_item_discount and not v_draft.allow_item_discount_stacking then
   raise exception 'Existing item discount not authorized for stacking';
 end if;
 -- Block known payment and settlement sources. Unknown ledger shapes fail closed
 -- when a relation exists but has no order_id column.
 foreach v_payment_table in array array[
   'gs_cash_payments','gs_cash_only_settlement_attestations',
   'gs_unified_payment_ledger','gs_payment_ledger','gs_credit_transactions',
   'gs_mixed_payment_finance_attestations'] loop
   if to_regclass('public.'||v_payment_table) is not null then
     if not exists(select 1 from information_schema.columns
        where table_schema='public' and table_name=v_payment_table and column_name='order_id') then
       raise exception 'Payment ledger requires reconciliation before discount: %',v_payment_table;
     end if;
     execute format('select exists(select 1 from public.%I where order_id=$1)',v_payment_table)
       into v_has_payment using p_order_id;
     if v_has_payment then raise exception 'Payment/settlement already recorded: %',v_payment_table; end if;
   end if;
 end loop;
 return jsonb_build_object(
   'order_id',p_order_id,'draft_id',v_draft.id,
   'source_total_iqd',v_draft.source_total_iqd,
   'bill_discount_iqd',v_draft.bill_discount_iqd,
   'proposed_total_iqd',v_draft.proposed_total_iqd,
   'approved_by',v_draft.approved_by,'approved_at',v_draft.approved_at,
   'status','preview_only_not_applied');
end; $$;
revoke all on function public.gs_admin_bill_discount_invoice_quote(bigint) from public,anon;
grant execute on function public.gs_admin_bill_discount_invoice_quote(bigint) to authenticated;
