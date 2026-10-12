-- Upgrade 62 DRAFT: harden cash collection against competing payment evidence.
-- Replaces gs_record_cash_payment, preserving existing RPC signature.
-- FAIL CLOSED when an order has external payment evidence or an owner waiver
-- pending/verified, until a unified settlement writer exists.
create or replace function public.gs_record_cash_payment(
 p_order_id bigint, p_amount_iqd bigint, p_reference uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare
 v_order public.gs_orders%rowtype;
 v_due bigint; v_paid bigint;
 v_existing public.gs_cash_payments%rowtype;
 v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_create') then
  raise exception 'Not authorized to collect cash';
 end if;
 if p_order_id is null or p_reference is null or p_amount_iqd is null
    or p_amount_iqd<=0 then
  raise exception 'Invalid payment request';
 end if;
 -- All writers for this order must use the same order-row lock.
 select * into v_order from public.gs_orders
   where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 -- Idempotent retries return the original receipt, not a second charge.
 select * into v_existing from public.gs_cash_payments
  where reference=p_reference;
 if found then
  if v_existing.order_id=p_order_id
     and v_existing.amount_iqd=p_amount_iqd then
   return v_existing.id;
  end if;
  raise exception 'Payment reference already used';
 end if;
 if v_order.status='cancelled' then
  raise exception 'Cannot pay a cancelled order';
 end if;
 if exists(select 1 from public.gs_external_payment_evidence e
   where e.order_id=p_order_id
     and e.verification_status in ('pending','verified','unverified')) then
  raise exception 'External payment evidence exists; reconcile before cash collection';
 end if;
 if exists(select 1 from public.gs_owner_guest_offers g
   where g.order_id=p_order_id and g.status in ('pending','verified')) then
  raise exception 'Owner complimentary offer exists; reconcile before cash collection';
 end if;
 if exists(select 1 from public.gs_table_bill_transfer_request_items i
   join public.gs_table_bill_transfer_requests r
     on r.id=i.transfer_request_id
   join public.gs_order_items oi on oi.id=i.order_item_id
   where oi.order_id=p_order_id
     and r.status in ('pending','approved','applied')) then
  raise exception 'Bill transfer request exists; reconcile before cash collection';
 end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_due
   from public.gs_order_items where order_id=p_order_id;
 select coalesce(sum(amount_iqd),0)::bigint into v_paid
   from public.gs_cash_payments where order_id=p_order_id;
 if v_due<=0 or p_amount_iqd>v_due-v_paid then
  raise exception 'Payment exceeds outstanding order amount';
 end if;
 insert into public.gs_cash_payments(order_id,amount_iqd,reference,collected_by)
 values(p_order_id,p_amount_iqd,p_reference,auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_record_cash_payment(bigint,bigint,uuid)
 from public,anon;
grant execute on function public.gs_record_cash_payment(bigint,bigint,uuid)
 to authenticated;

-- NOTE: Legacy or future payment writers not using the same row lock
-- are NOT protected by this RPC. Production must audit every writer.
