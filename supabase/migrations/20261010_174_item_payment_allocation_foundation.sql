-- Upgrade 174: item-level partial-payment allocation model and safe preview.
-- Intentionally NO payment posting: unified/legacy reconciliation is incomplete.
create table if not exists public.gs_item_payment_allocations (
 id bigint generated always as identity primary key,
 order_item_id bigint not null references public.gs_order_items(id) on delete restrict,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 payer_label text not null check(length(btrim(payer_label)) between 1 and 120),
 chair_label text,
 quantity integer not null check(quantity>0),
 amount_iqd bigint not null check(amount_iqd>0),
 payment_ledger_entry_id bigint not null references public.gs_unified_payment_ledger(id) on delete restrict,
 allocated_at timestamptz not null default now(),
 allocated_by uuid not null references auth.users(id),
 unique(payment_ledger_entry_id,order_item_id)
);
create index if not exists gs_item_payment_allocations_item_idx
 on public.gs_item_payment_allocations(order_item_id);
alter table public.gs_item_payment_allocations enable row level security;
revoke all on public.gs_item_payment_allocations from public,anon,authenticated;
-- Deliberately no insert/update/delete grants, policies or posting RPC.
create or replace function public.gs_prevent_item_allocation_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Item payment allocation records are immutable'; end; $$;
drop trigger if exists gs_item_allocation_immutable on public.gs_item_payment_allocations;
create trigger gs_item_allocation_immutable
 before update or delete on public.gs_item_payment_allocations
 for each row execute function public.gs_prevent_item_allocation_mutation();

create or replace function public.gs_preview_item_payment_allocation(
 p_order_item_id bigint,p_quantity integer)
returns table(
 order_id bigint,order_item_id bigint,item_quantity integer,
 previously_allocated_quantity bigint,requested_quantity integer,
 unit_price_iqd bigint,requested_amount_iqd bigint,
 legacy_cash_present boolean,unified_ledger_present boolean,
 external_evidence_present boolean,can_collect boolean,blocker_codes text[]
)
language plpgsql stable security definer set search_path='' as $$
declare v_item public.gs_order_items%rowtype;
 v_alloc bigint;v_cash boolean;v_ledger boolean;v_external boolean;
 v_blocks text[]:=array[]::text[];
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')) then
  raise exception 'Payment preview access denied';
 end if;
 if p_quantity is null or p_quantity<=0 then
  raise exception 'Requested quantity must be positive';
 end if;
 select * into v_item from public.gs_order_items
 where id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 select coalesce(sum(a.quantity),0)::bigint into v_alloc
 from public.gs_item_payment_allocations a where a.order_item_id=v_item.id;
 select exists(select 1 from public.gs_cash_payments c
  where c.order_id=v_item.order_id) into v_cash;
 select exists(select 1 from public.gs_unified_payment_ledger l
  where l.order_id=v_item.order_id) into v_ledger;
 select exists(select 1 from public.gs_external_payment_evidence e
  where e.order_id=v_item.order_id) into v_external;
 if p_quantity>v_item.quantity-v_alloc then
  v_blocks:=array_append(v_blocks,'QUANTITY_EXCEEDS_UNALLOCATED');
 end if;
 if v_item.unit_price_iqd<=0 then
  v_blocks:=array_append(v_blocks,'INVALID_ITEM_PRICE');
 end if;
 if v_cash then v_blocks:=array_append(v_blocks,'LEGACY_CASH_RECONCILIATION_REQUIRED'); end if;
 if v_ledger then v_blocks:=array_append(v_blocks,'UNIFIED_LEDGER_RECONCILIATION_REQUIRED'); end if;
 if v_external then v_blocks:=array_append(v_blocks,'EXTERNAL_PAYMENT_RECONCILIATION_REQUIRED'); end if;
 v_blocks:=array_append(v_blocks,'PAYMENT_POSTING_NOT_IMPLEMENTED');
 return query select v_item.order_id,v_item.id,v_item.quantity,v_alloc,
 p_quantity,v_item.unit_price_iqd,
 (p_quantity::bigint*v_item.unit_price_iqd)::bigint,
 v_cash,v_ledger,v_external,false,v_blocks;
end; $$;
revoke all on function public.gs_preview_item_payment_allocation(bigint,integer)
 from public,anon;
grant execute on function public.gs_preview_item_payment_allocation(bigint,integer)
 to authenticated;
