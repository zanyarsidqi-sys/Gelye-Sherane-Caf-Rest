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
    where order_id=v_order_id) then
  raise exception using errcode='P0001',
   message='Order is cash-settlement attested; financial and order mutations are blocked';
 end if;
 -- Moving an existing order item to another order must protect BOTH orders.
 if TG_TABLE_NAME='gs_order_items' and TG_OP='UPDATE'
    and old.order_id is distinct from new.order_id then
  if exists(select 1 from public.gs_cash_only_settlement_attestations
    where order_id=old.order_id) then
   raise exception 'Cannot move items out of a cash-settlement attested order';
  end if;
 end if;
 if TG_OP='DELETE' then return old;end if;
 return new;
end; $$;
revoke all on function public.gs_protect_cash_attested_order() from public,anon,authenticated;
-- Trigger on orders: no status or totals can be changed after attestation.
drop trigger if exists gs_guard_attested_orders on public.gs_orders;
create trigger gs_guard_attested_orders before update or delete on public.gs_orders
 for each row execute function public.gs_protect_cash_attested_order();
-- Existing priced line items cannot be edited or removed after attestation.
drop trigger if exists gs_guard_attested_order_items on public.gs_order_items;
create trigger gs_guard_attested_order_items before insert or update or delete on public.gs_order_items
 for each row execute function public.gs_protect_cash_attested_order();
-- New payments, reversals, corrections or unverified evidence cannot appear
-- after attestation. The original receipts remain append-only as before.
drop trigger if exists gs_guard_attested_gs_cash_payments on public.gs_cash_payments;
create trigger gs_guard_attested_gs_cash_payments before insert or update or delete on public.gs_cash_payments
 for each row execute function public.gs_protect_cash_attested_order();
drop trigger if exists gs_guard_attested_gs_unified_payment_ledger on public.gs_unified_payment_ledger;
create trigger gs_guard_attested_gs_unified_payment_ledger before insert or update or delete on public.gs_unified_payment_ledger
 for each row execute function public.gs_protect_cash_attested_order();
drop trigger if exists gs_guard_attested_gs_cash_correction_postings on public.gs_cash_correction_postings;
create trigger gs_guard_attested_gs_cash_correction_postings before insert or update or delete on public.gs_cash_correction_postings
 for each row execute function public.gs_protect_cash_attested_order();
drop trigger if exists gs_guard_attested_gs_external_payment_evidence on public.gs_external_payment_evidence;
create trigger gs_guard_attested_gs_external_payment_evidence before insert or update or delete on public.gs_external_payment_evidence
 for each row execute function public.gs_protect_cash_attested_order();
drop trigger if exists gs_guard_attested_gs_owner_guest_offers on public.gs_owner_guest_offers;
create trigger gs_guard_attested_gs_owner_guest_offers before insert or update or delete on public.gs_owner_guest_offers
 for each row execute function public.gs_protect_cash_attested_order();
