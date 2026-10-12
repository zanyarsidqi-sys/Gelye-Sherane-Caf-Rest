-- Upgrade 134: apply existing post-attestation mutation guards to mixed payments.
-- Upgrade 114: freeze attested cash-only orders against later mutations.
-- Every guarded writer serializes on the parent order row; this is essential
-- to prevent a concurrent insert slipping in after the finance attestation.
create or replace function public.gs_protect_cash_attested_order()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_order_id bigint;v_locked bigint;
begin
 if TG_TABLE_NAME='gs_orders' then
  v_order_id:=case when TG_OP='DELETE' then old.id else new.id end;
 elsif TG_TABLE_NAME='gs_order_items' then
  v_order_id:=case when TG_OP='DELETE' then old.order_id else new.order_id end;
 elsif TG_TABLE_NAME in ('gs_cash_payments','gs_unified_payment_ledger',
   'gs_cash_correction_postings','gs_external_payment_evidence',
   'gs_owner_guest_offers') then
  v_order_id:=case when TG_OP='DELETE' then old.order_id else new.order_id end;
 else
  raise exception 'Unsupported settlement guard source';
 end if;
 -- Do not lock the same order row recursively when the trigger is on gs_orders.
 if TG_TABLE_NAME<>'gs_orders' then
  select id into v_locked from public.gs_orders where id=v_order_id for update;
  if not found then raise exception 'Order not found for settlement mutation'; end if;
 end if;
 if exists(select 1 from public.gs_cash_only_settlement_attestations
    where order_id=v_order_id)
 or exists(select 1 from public.gs_mixed_payment_settlement_attestations
    where order_id=v_order_id) then
  raise exception using errcode='P0001',
   message='Order is finance-settlement attested; financial and order mutations are blocked';
 end if;
 -- Moving an existing order item to another order must protect BOTH orders.
 if TG_TABLE_NAME='gs_order_items' and TG_OP='UPDATE'
    and old.order_id is distinct from new.order_id then
  if exists(select 1 from public.gs_cash_only_settlement_attestations
    where order_id=old.order_id)
 or exists(select 1 from public.gs_mixed_payment_settlement_attestations
    where order_id=old.order_id) then
   raise exception 'Cannot move items out of a finance-attested order';
  end if;
 end if;
 if TG_OP='DELETE' then return old;end if;
 return new;
end; $$;

-- Upgrade 128: block post-attestation bill-transfer request insertion.
-- Previously, attested orders were protected from order/item/payment writes,
-- but transfer-request ITEMS reference existing priced items without editing them.
-- Such a new request could create a conflicting transfer after finance approval.
create or replace function public.gs_guard_attested_bill_transfer_request_item()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_order_id bigint;
begin
 if TG_OP='DELETE' then
   select order_id into v_order_id from public.gs_order_items where id=old.order_item_id;
 else
   select order_id into v_order_id from public.gs_order_items where id=new.order_item_id;
 end if;
 if v_order_id is null then
   raise exception 'Transfer request item does not reference an existing order item';
 end if;
 -- Same parent order row lock used by settlement attestation.
 perform 1 from public.gs_orders where id=v_order_id for update;
 if exists(select 1 from public.gs_cash_only_settlement_attestations
           where order_id=v_order_id)
   or exists(select 1 from public.gs_mixed_payment_settlement_attestations
           where order_id=v_order_id) then
   raise exception 'Finance-attested order cannot gain or change bill transfer requests';
 end if;
 if TG_OP='UPDATE' and old.order_item_id is distinct from new.order_item_id then
   select order_id into v_order_id from public.gs_order_items where id=old.order_item_id;
   if v_order_id is null then raise exception 'Original transfer order item missing'; end if;
   perform 1 from public.gs_orders where id=v_order_id for update;
   if exists(select 1 from public.gs_cash_only_settlement_attestations
             where order_id=v_order_id)
     or exists(select 1 from public.gs_mixed_payment_settlement_attestations
             where order_id=v_order_id) then
     raise exception 'Finance-attested source order cannot lose transfer request linkage';
   end if;
 end if;
 if TG_OP='DELETE' then return old; end if;
 return new;
end; $$;
