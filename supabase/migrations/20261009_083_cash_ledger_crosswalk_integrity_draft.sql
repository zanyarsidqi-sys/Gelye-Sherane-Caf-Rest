-- Upgrade 83: harden trusted cash-to-ledger reconciliation crosswalk.
-- No client insert grants; trusted migrations must insert consistent links.
create or replace function public.gs_validate_cash_ledger_crosswalk()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_cash public.gs_cash_payments%rowtype;
        v_ledger public.gs_unified_payment_ledger%rowtype;
begin
 if tg_op <> 'INSERT' then
  raise exception 'Reconciliation links are immutable; investigate and correct using a reviewed migration';
 end if;
 select * into v_cash from public.gs_cash_payments
  where id=new.legacy_cash_id for share;
 if not found then raise exception 'Cash receipt missing'; end if;
 select * into v_ledger from public.gs_unified_payment_ledger
  where id=new.ledger_entry_id for share;
 if not found then raise exception 'Ledger entry missing'; end if;
 if v_cash.order_id is distinct from v_ledger.order_id
    or v_cash.amount_iqd is distinct from v_ledger.amount_iqd
    or v_ledger.entry_type <> 'cash'
    or v_ledger.direction <> 'credit'
    or v_ledger.source_system <> 'legacy_cash'
 then
  raise exception 'Cash/ledger mismatch: crosswalk rejected';
 end if;
 if new.reconciliation_reference is null
   or length(btrim(new.reconciliation_reference))=0 then
  raise exception 'Reconciliation reference required';
 end if;
 return new;
end; $$;
revoke all on function public.gs_validate_cash_ledger_crosswalk() from public,anon,authenticated;
drop trigger if exists gs_cash_ledger_crosswalk_integrity on public.gs_cash_ledger_reconciliation_links;
create trigger gs_cash_ledger_crosswalk_integrity
 before insert or update or delete on public.gs_cash_ledger_reconciliation_links
 for each row execute function public.gs_validate_cash_ledger_crosswalk();
-- Prevent later ledger edits from invalidating a previously matched crosswalk.
create or replace function public.gs_protect_reconciled_ledger_row()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.gs_cash_ledger_reconciliation_links x
           where x.ledger_entry_id=old.id) then
  raise exception 'Reconciled ledger entry is immutable; use a separately audited reversal';
 end if;
 return case when tg_op='DELETE' then old else new end;
end; $$;
revoke all on function public.gs_protect_reconciled_ledger_row() from public,anon,authenticated;
drop trigger if exists gs_protect_reconciled_ledger_row on public.gs_unified_payment_ledger;
create trigger gs_protect_reconciled_ledger_row
 before update or delete on public.gs_unified_payment_ledger
 for each row execute function public.gs_protect_reconciled_ledger_row();
-- Protect the other half of the match as well.
create or replace function public.gs_protect_reconciled_cash_row()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.gs_cash_ledger_reconciliation_links x
           where x.legacy_cash_id=old.id) then
  raise exception 'Reconciled cash receipt is immutable; use a separately audited correction';
 end if;
 return case when tg_op='DELETE' then old else new end;
end; $$;
revoke all on function public.gs_protect_reconciled_cash_row() from public,anon,authenticated;
drop trigger if exists gs_protect_reconciled_cash_row on public.gs_cash_payments;
create trigger gs_protect_reconciled_cash_row
 before update or delete on public.gs_cash_payments
 for each row execute function public.gs_protect_reconciled_cash_row();
-- This enforces integrity of matched records; it does not verify payment,
-- migrate legacy cash, enable transfer execution, or confirm settlement.
