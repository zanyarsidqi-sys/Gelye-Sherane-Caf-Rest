-- Upgrade 248: close the legacy cash-collection bypass for locked discounted invoices.
-- Fail closed until a separately reviewed settlement writer uses snapshot amount_due_iqd.
-- This migration DOES NOT charge, debit, or settle locked discounted invoices.
create or replace function public.gs_record_cash_payment(p_order_id bigint, p_amount_iqd bigint, p_reference uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
 v_order public.gs_orders%rowtype;
 v_due bigint;
 v_paid bigint;
 v_existing public.gs_cash_payments%rowtype;
 v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_create') then
   raise exception 'Not authorized to collect cash';
 end if;
 if p_order_id is null or p_reference is null or p_amount_iqd is null or p_amount_iqd <= 0 then
   raise exception 'Invalid payment request';
 end if;
 -- Keep all cooperating payment writers serialized on the parent order.
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 -- IMPORTANT: never use the undiscounted order-item sum to collect against a locked invoice.
 -- Block even idempotent retries until an audited locked-invoice payment writer exists.
 if exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id) then
   raise exception 'Locked discounted invoice: legacy cash collection is disabled; use verified discounted settlement workflow';
 end if;
 select * into v_existing from public.gs_cash_payments where reference=p_reference;
 if found then
   if v_existing.order_id=p_order_id and v_existing.amount_iqd=p_amount_iqd then
     return v_existing.id;
   end if;
   raise exception 'Payment reference already used';
 end if;
 if v_order.status in ('cancelled','paid','settled','closed','completed') then
   raise exception 'Cannot collect cash on cancelled or completed order';
 end if;
 select coalesce(sum(line_total_iqd),0) into v_due from public.gs_order_items where order_id=p_order_id;
 select coalesce(sum(amount_iqd),0) into v_paid from public.gs_cash_payments where order_id=p_order_id;
 if v_due <= 0 or p_amount_iqd > v_due-v_paid then
   raise exception 'Payment exceeds outstanding order amount';
 end if;
 insert into public.gs_cash_payments(order_id,amount_iqd,reference,collected_by)
 values(p_order_id,p_amount_iqd,p_reference,auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_record_cash_payment(bigint,bigint,uuid) from public,anon;
grant execute on function public.gs_record_cash_payment(bigint,bigint,uuid) to authenticated;

-- Read-only, admin-scoped readiness check for eventual locked-invoice cash settlement.
create or replace function public.gs_locked_discount_cash_readiness(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_snapshot public.gs_admin_discount_invoice_snapshots%rowtype;
 v_intent public.gs_locked_discount_payment_intents%rowtype;
 v_audit jsonb;
begin
 if auth.uid() is null or not exists
   (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid()) then
   raise exception 'Admin authorization required';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order'; end if;
 select * into v_snapshot from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id;
 select * into v_intent from public.gs_locked_discount_payment_intents where order_id=p_order_id;
 v_audit := public.gs_locked_discount_payment_source_audit(p_order_id);
 return jsonb_build_object(
  'order_id',p_order_id,'snapshot_exists',v_snapshot.id is not null,
  'payment_intent_exists',v_intent.id is not null,
  'snapshot_id',v_snapshot.id,'amount_due_iqd',v_snapshot.amount_due_iqd,
  'intent_amount_matches',coalesce(v_intent.amount_due_iqd=v_snapshot.amount_due_iqd,false),
  'source_audit',v_audit,
  'legacy_cash_writer_blocked',true,'locked_cash_capture_enabled',false,
  'reason','Locked discounted invoices require a reviewed atomic settlement writer; no cash capture is enabled',
  'read_only',true);
end; $$;
revoke all on function public.gs_locked_discount_cash_readiness(bigint) from public,anon;
grant execute on function public.gs_locked_discount_cash_readiness(bigint) to authenticated;
