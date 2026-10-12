-- Upgrade 65 DRAFT: prevent financial-history drift on order items.
-- An order item whose order has payment evidence, an owner offer, or an
-- active transfer request must not have its price/quantity/product changed.
-- This is a fail-closed integrity guard, not a settlement or transfer engine.
create or replace function public.gs_guard_order_item_financial_integrity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_order_id bigint;
begin
 v_order_id := case when tg_op='DELETE' then old.order_id else new.order_id end;
 -- Coordinate with the cash writer and future payment writers.
 perform 1 from public.gs_orders where id=v_order_id for update;
 if tg_op='UPDATE' and new.order_id is distinct from old.order_id then
   raise exception 'Moving an existing item to a different order is forbidden';
 end if;
 if exists(select 1 from public.gs_cash_payments p where p.order_id=v_order_id)
    or exists(select 1 from public.gs_external_payment_evidence e where e.order_id=v_order_id)
    or exists(select 1 from public.gs_owner_guest_offers g where g.order_id=v_order_id
       and g.status in ('pending','verified'))
    or exists(select 1 from public.gs_table_bill_transfer_request_items ri
       join public.gs_table_bill_transfer_requests r on r.id=ri.transfer_request_id
       join public.gs_order_items oi on oi.id=ri.order_item_id
       where oi.order_id=v_order_id and r.status in ('pending','approved','applied'))
 then
   if tg_op='DELETE' or (tg_op='UPDATE' and
      (new.quantity is distinct from old.quantity or
       new.unit_price_iqd is distinct from old.unit_price_iqd or
       new.product_id is distinct from old.product_id)) then
     raise exception 'Financially referenced order item is immutable; use an audited adjustment workflow';
   end if;
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end; $$;
revoke all on function public.gs_guard_order_item_financial_integrity() from public,anon,authenticated;
drop trigger if exists gs_guard_order_item_financial_integrity_trg on public.gs_order_items;
create trigger gs_guard_order_item_financial_integrity_trg
before update or delete on public.gs_order_items
for each row execute function public.gs_guard_order_item_financial_integrity();

-- Pending: audited refunds, cancellations, correction notes, verified
-- noncash writers, owner approval, and actual bill-transfer execution.
-- WARNING: this trigger may affect existing edit flows; do not deploy
-- until migration compatibility and regression testing are complete.
