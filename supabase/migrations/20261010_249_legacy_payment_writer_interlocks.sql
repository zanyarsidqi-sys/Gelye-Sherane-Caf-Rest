-- Upgrade 249: database-level interlock for legacy payment writers.
-- This is a deliberately fail-closed interim guard, NOT discounted settlement.
-- Run after migration 248. Normal (non-snapshot) orders remain unchanged.
create or replace function public.gs_guard_locked_discount_payment_write()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_order_id bigint;
begin
  v_order_id := new.order_id;
  if v_order_id is null then
    raise exception 'Payment row must have an order';
  end if;
  -- Serialize with snapshot creation and all cooperative order writers.
  perform 1 from public.gs_orders where id=v_order_id for update;
  if exists (
    select 1 from public.gs_admin_discount_invoice_snapshots
    where order_id=v_order_id
  ) then
    raise exception 'Locked discounted invoice: legacy payment posting blocked for order %',v_order_id;
  end if;
  return new;
end; $$;
revoke all on function public.gs_guard_locked_discount_payment_write() from public,anon,authenticated;

-- Protect all known payment posting and settlement entry points at the table level,
-- even when a SECURITY DEFINER RPC bypasses the earlier gs_record_cash_payment guard.
-- Only INSERT is guarded here: legacy correction/reversal and migration maintenance
-- require separate review, not a blanket mutation prohibition.
do $$
declare v_table text;
begin
  foreach v_table in array array[
    'gs_cash_payments',
    'gs_external_payment_evidence',
    'gs_unified_payment_ledger',
    'gs_cash_only_settlement_attestations',
    'gs_mixed_payment_settlement_attestations',
    'gs_item_payment_allocations'
  ] loop
    if to_regclass(format('public.%I',v_table)) is null then
      raise exception 'Required payment table missing: %',v_table;
    end if;
    execute format('drop trigger if exists gs_guard_locked_discount_insert on public.%I',v_table);
    execute format('create trigger gs_guard_locked_discount_insert before insert on public.%I for each row execute function public.gs_guard_locked_discount_payment_write()',v_table);
  end loop;
end $$;

-- Diagnostic for Admin: reports guard coverage without attempting a charge.
create or replace function public.gs_locked_discount_payment_guard_status(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_table text; v_status jsonb := '{}'::jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.gs_cafe_discount_admins where user_id=auth.uid()
  ) then raise exception 'Admin authorization required'; end if;
  if p_order_id is null or p_order_id<=0 then raise exception 'Invalid order'; end if;
  foreach v_table in array array[
    'gs_cash_payments','gs_external_payment_evidence','gs_unified_payment_ledger',
    'gs_cash_only_settlement_attestations','gs_mixed_payment_settlement_attestations',
    'gs_item_payment_allocations'
  ] loop
    v_status := v_status || jsonb_build_object(v_table,exists(
      select 1 from pg_catalog.pg_trigger t
      join pg_catalog.pg_class c on c.oid=t.tgrelid
      join pg_catalog.pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=v_table
      and t.tgname='gs_guard_locked_discount_insert' and not t.tgisinternal and t.tgenabled<>'D'
    ));
  end loop;
  return jsonb_build_object('order_id',p_order_id,
    'locked_discount_invoice_exists',exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id),
    'legacy_insert_guards',v_status,'discounted_settlement_enabled',false,
    'warning','This only guards known legacy insert paths; no discounted payment is posted');
end; $$;
revoke all on function public.gs_locked_discount_payment_guard_status(bigint) from public,anon;
grant execute on function public.gs_locked_discount_payment_guard_status(bigint) to authenticated;
