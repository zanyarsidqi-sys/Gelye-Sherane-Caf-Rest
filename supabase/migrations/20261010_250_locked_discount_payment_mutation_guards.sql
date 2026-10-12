-- Upgrade 250: fail-closed protection for UPDATE/DELETE on legacy payment rows.
-- This is a guard, not a settlement writer. Apply after 249.
-- Handles moving a payment row onto or away from a locked invoice.
create or replace function public.gs_guard_locked_discount_payment_mutation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_old_order bigint; v_new_order bigint;
begin
  v_old_order := old.order_id;
  if tg_op = 'UPDATE' then v_new_order := new.order_id; else v_new_order := null; end if;
  if v_old_order is null or (tg_op = 'UPDATE' and v_new_order is null) then
    raise exception 'Payment row requires an order';
  end if;
  -- Deterministic locking order avoids deadlocks when a row is reassigned.
  perform 1 from public.gs_orders
    where id in (v_old_order, v_new_order) order by id for update;
  if exists (select 1 from public.gs_admin_discount_invoice_snapshots
             where order_id in (v_old_order, v_new_order)) then
    raise exception 'Locked discounted invoice: legacy payment % blocked',tg_op;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.gs_guard_locked_discount_payment_mutation() from public,anon,authenticated;

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'gs_cash_payments', 'gs_external_payment_evidence',
    'gs_unified_payment_ledger', 'gs_cash_only_settlement_attestations',
    'gs_mixed_payment_settlement_attestations', 'gs_item_payment_allocations'
  ] loop
    if to_regclass(format('public.%I',v_table)) is null then
      raise exception 'Required payment table missing: %',v_table;
    end if;
    execute format('drop trigger if exists gs_guard_locked_discount_mutation on public.%I',v_table);
    execute format('create trigger gs_guard_locked_discount_mutation before update or delete on public.%I for each row execute function public.gs_guard_locked_discount_payment_mutation()',v_table);
  end loop;
end $$;

-- Read-only diagnostic; reports both insert and update/delete guards.
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
    v_status := v_status || jsonb_build_object(v_table,jsonb_build_object(
      'insert_guard',exists(
        select 1 from pg_catalog.pg_trigger t
        join pg_catalog.pg_class c on c.oid=t.tgrelid
        join pg_catalog.pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public' and c.relname=v_table
        and t.tgname='gs_guard_locked_discount_insert'
        and not t.tgisinternal and t.tgenabled<>'D' and (t.tgtype & 4)=4
      ),
      'update_delete_guard',exists(
        select 1 from pg_catalog.pg_trigger t
        join pg_catalog.pg_class c on c.oid=t.tgrelid
        join pg_catalog.pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public' and c.relname=v_table
        and t.tgname='gs_guard_locked_discount_mutation'
        and not t.tgisinternal and t.tgenabled<>'D'
        and (t.tgtype & 16)=16 and (t.tgtype & 8)=8
      )
    ));
  end loop;
  return jsonb_build_object('order_id',p_order_id,
    'locked_discount_invoice_exists',exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id),
    'legacy_payment_guards',v_status,'discounted_settlement_enabled',false,
    'warning','Known legacy payment tables guarded for INSERT/UPDATE/DELETE; other writers and settlement remain unverified');
end; $$;
revoke all on function public.gs_locked_discount_payment_guard_status(bigint) from public,anon;
grant execute on function public.gs_locked_discount_payment_guard_status(bigint) to authenticated;
