-- Upgrade 164: reapply request RPC with provider/ledger guard and item validation.
-- Upgrade 60 DRAFT: atomic, idempotent REQUEST of an unpaid bill transfer.
-- NO BILL IS MOVED. Execution is disabled until unified noncash settlement
-- and allocation safeguards are implemented.
alter table public.gs_table_bill_transfer_requests
 add column if not exists request_key uuid;
create unique index if not exists gs_table_transfer_request_key_unique
 on public.gs_table_bill_transfer_requests(request_key)
 where request_key is not null;

create or replace function public.gs_request_table_bill_transfer(
 p_source_visit_id bigint, p_destination_visit_id bigint,
 p_order_item_id bigint, p_quantity integer, p_reason text, p_request_key uuid
) returns bigint
language plpgsql security definer set search_path='' as $$
declare
 v_source public.gs_table_visits%rowtype;
 v_dest public.gs_table_visits%rowtype;
 v_item public.gs_order_items%rowtype;
 v_order public.gs_orders%rowtype;
 v_existing public.gs_table_bill_transfer_requests%rowtype;
 v_id bigint;
begin
 if auth.uid() is null
    or not public.gs_can_access('table_orders','can_edit')
    or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Bill transfer request permission denied';
 end if;
 if p_source_visit_id is null or p_destination_visit_id is null
    or p_source_visit_id=p_destination_visit_id or p_order_item_id is null
    or p_quantity is null or p_quantity<=0 or p_request_key is null
    or p_reason is null or length(btrim(p_reason))<5
    or length(p_reason)>500 then
   raise exception 'Invalid transfer request';
 end if;
 -- Idempotency is serialized even when no request row exists yet.
 perform pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
 select * into v_existing from public.gs_table_bill_transfer_requests
  where request_key=p_request_key for update;
 if found then
   if v_existing.source_visit_id=p_source_visit_id
      and v_existing.destination_visit_id=p_destination_visit_id
      and v_existing.reason=btrim(p_reason)
      and exists(select 1 from public.gs_table_bill_transfer_request_items x
       where x.transfer_request_id=v_existing.id
         and x.order_item_id=p_order_item_id
         and x.requested_quantity=p_quantity)
   then return v_existing.id; end if;
   raise exception 'Request key already used for different transfer';
 end if;
 -- Stable lock ordering for concurrent table moves.
 perform 1 from public.gs_table_visits
  where id in (p_source_visit_id,p_destination_visit_id)
  order by id for update;
 select * into v_source from public.gs_table_visits
  where id=p_source_visit_id and status='active';
 select * into v_dest from public.gs_table_visits
  where id=p_destination_visit_id and status='active';
 if v_source.id is null or v_dest.id is null
    or v_source.table_id=v_dest.table_id then
   raise exception 'Two distinct active table visits required';
 end if;
 if exists(select 1 from public.gs_cafe_tables t
   where t.id in (v_source.table_id,v_dest.table_id)
    and (not t.occupied or t.cleaning_needed)) then
   raise exception 'Table unavailable or cleaning'; end if;
 select * into v_item from public.gs_order_items
  where id=p_order_item_id for update;
 if not found or v_item.quantity is null or v_item.quantity<=0
    or p_quantity>v_item.quantity or v_item.unit_price_iqd is null
    or v_item.unit_price_iqd<0 then
   raise exception 'Invalid item quantity'; end if;
 select * into v_order from public.gs_orders
  where id=v_item.order_id and table_visit_id=p_source_visit_id
    and is_motel=false for update;
 if not found or v_order.status='cancelled' then
   raise exception 'Item is not a valid source visit order'; end if;
 if exists(select 1 from public.gs_cash_payments p
   where p.order_id=v_order.id) then
   raise exception 'Paid order requires unified payment allocation review';
 end if;
 -- A request is not an allocation. Do not allow requests against orders
 -- with any ledger activity or external evidence, even if cash receipts are zero.
 if exists(select 1 from public.gs_unified_payment_ledger l
   where l.order_id=v_order.id) then
   raise exception 'Ledger activity requires finance reconciliation before transfer';
 end if;
 if exists(select 1 from public.gs_external_payment_evidence e
   where e.order_id=v_order.id) then
   raise exception 'External payment evidence requires finance reconciliation before transfer';
 end if;
 if exists(select 1 from public.gs_owner_guest_offers g
   where g.order_id=v_order.id and g.status in ('pending','verified')) then
   raise exception 'Owner complimentary offer requires review';
 end if;
 if exists(select 1 from public.gs_table_bill_transfer_request_items x
   join public.gs_table_bill_transfer_requests r on r.id=x.transfer_request_id
   where x.order_item_id=p_order_item_id
     and r.status in ('pending','approved','applied')) then
   raise exception 'Item already included in active transfer request';
 end if;
 insert into public.gs_table_bill_transfer_requests(
  source_visit_id,destination_visit_id,requested_by,status,reason,request_key)
 values(p_source_visit_id,p_destination_visit_id,auth.uid(),'pending',
  btrim(p_reason),p_request_key) returning id into v_id;
 insert into public.gs_table_bill_transfer_request_items(
  transfer_request_id,order_item_id,requested_quantity)
 values(v_id,p_order_item_id,p_quantity);
 return v_id;
end; $$;
revoke all on function public.gs_request_table_bill_transfer(
 bigint,bigint,bigint,integer,text,uuid) from public,anon;
grant execute on function public.gs_request_table_bill_transfer(
 bigint,bigint,bigint,integer,text,uuid) to authenticated;

-- The request function never changes order items, visits, balances, prices,
-- payments, occupancy or revenue. A transfer EXECUTION function is withheld:
-- no authoritative unified cash/card/credit/online/waiver ledger exists.
