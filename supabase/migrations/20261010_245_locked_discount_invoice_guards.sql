-- Upgrade 245: Protect immutable Admin discount invoice snapshots from order mutations.
-- Payment settlement is deliberately NOT enabled. Run staging regression tests before production.
-- Lock the parent order to serialize with snapshot creation and cooperating writers.
create or replace function public.gs_guard_locked_discount_order_item()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_order_id bigint;
begin
  v_order_id := case when tg_op='DELETE' then old.order_id else new.order_id end;
  perform 1 from public.gs_orders where id=v_order_id for update;
  if exists (select 1 from public.gs_admin_discount_invoice_snapshots s
             where s.order_id=v_order_id) then
    raise exception 'Order has a locked discounted invoice; item changes require an audited correction workflow';
  end if;
  if tg_op='UPDATE' and new.order_id is distinct from old.order_id then
    perform 1 from public.gs_orders where id=new.order_id for update;
    if exists (select 1 from public.gs_admin_discount_invoice_snapshots s
               where s.order_id=new.order_id) then
      raise exception 'Cannot move items into a locked discounted invoice';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.gs_guard_locked_discount_order_item() from public,anon,authenticated;
drop trigger if exists gs_guard_locked_discount_order_item_trg on public.gs_order_items;
create trigger gs_guard_locked_discount_order_item_trg
before insert or update or delete on public.gs_order_items
for each row execute function public.gs_guard_locked_discount_order_item();

-- Prevent altering order destination, mode or status after a discounted invoice is locked.
-- A separate audited settlement procedure will be required to transition its status.
create or replace function public.gs_guard_locked_discount_order_header()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists(select 1 from public.gs_admin_discount_invoice_snapshots s where s.order_id=old.id) then
    if tg_op='DELETE' then
      raise exception 'Cannot delete an order with a locked discounted invoice';
    end if;
    if new.destination is distinct from old.destination
       or new.is_motel is distinct from old.is_motel
       or new.tourism_mode is distinct from old.tourism_mode
       or new.status is distinct from old.status then
      raise exception 'Locked discounted invoice prevents order header changes';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.gs_guard_locked_discount_order_header() from public,anon,authenticated;
drop trigger if exists gs_guard_locked_discount_order_header_trg on public.gs_orders;
create trigger gs_guard_locked_discount_order_header_trg
before update or delete on public.gs_orders
for each row execute function public.gs_guard_locked_discount_order_header();

-- Read-only locked payable contract for a future payment engine.
-- No payment, ledger, or bill state is changed by this function.
create or replace function public.gs_get_locked_discount_payable(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v public.gs_admin_discount_invoice_snapshots%rowtype;
begin
  if auth.uid() is null or not exists
     (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
  then raise exception 'Admin authorization required'; end if;
  if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order ID'; end if;
  select * into v from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id;
  if not found then
    return jsonb_build_object('order_id',p_order_id,'status','no_locked_invoice',
      'payment_authorized',false);
  end if;
  return jsonb_build_object('order_id',v.order_id,'snapshot_id',v.id,
    'source_total_iqd',v.source_total_iqd,'bill_discount_iqd',v.bill_discount_iqd,
    'amount_due_iqd',v.amount_due_iqd,'status','locked_unpaid_invoice',
    'payment_authorized',false,'read_only',true);
end; $$;
revoke all on function public.gs_get_locked_discount_payable(bigint) from public,anon;
grant execute on function public.gs_get_locked_discount_payable(bigint) to authenticated;
