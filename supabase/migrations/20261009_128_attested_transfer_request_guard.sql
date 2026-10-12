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
           where order_id=v_order_id) then
   raise exception 'Finance-attested order cannot gain or change bill transfer requests';
 end if;
 if TG_OP='UPDATE' and old.order_item_id is distinct from new.order_item_id then
   select order_id into v_order_id from public.gs_order_items where id=old.order_item_id;
   if v_order_id is null then raise exception 'Original transfer order item missing'; end if;
   perform 1 from public.gs_orders where id=v_order_id for update;
   if exists(select 1 from public.gs_cash_only_settlement_attestations
             where order_id=v_order_id) then
     raise exception 'Finance-attested source order cannot lose transfer request linkage';
   end if;
 end if;
 if TG_OP='DELETE' then return old; end if;
 return new;
end; $$;
revoke all on function public.gs_guard_attested_bill_transfer_request_item()
 from public,anon,authenticated;
drop trigger if exists gs_guard_attested_bill_transfer_request_item
 on public.gs_table_bill_transfer_request_items;
create trigger gs_guard_attested_bill_transfer_request_item
 before insert or update or delete
 on public.gs_table_bill_transfer_request_items
 for each row execute function public.gs_guard_attested_bill_transfer_request_item();
