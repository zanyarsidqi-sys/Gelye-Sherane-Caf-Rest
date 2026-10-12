-- DRAFT / CASH-ONLY SAFETY GATE: no automatic release and no inferred shisha purchase.
-- This stage does not treat pending card/credit transfers or screenshots as paid.
-- Review and test with real payment ledgers before deployment.
alter table public.gs_cafe_tables
 add column if not exists guests_departed_at timestamptz,
 add column if not exists cleaning_needed boolean not null default false;

-- The cashier confirms physical departure; the database independently checks
-- all non-cancelled table orders are served and fully covered by recorded cash.
-- Noncash payment support is deliberately blocked until a verified settlement
-- ledger can be included in the balance calculation.
create or replace function public.gs_mark_table_departed_for_cleaning(
 p_table_id bigint, p_shisha_collection_confirmed boolean default false
) returns table(cleaning_task_id bigint, shisha_task_id bigint)
language plpgsql security definer set search_path=''
as $$
declare v_table public.gs_cafe_tables%rowtype;
 v_order record; v_cleaning bigint; v_shisha bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit')
    or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Checkout permission denied'; end if;
 select * into v_table from public.gs_cafe_tables where id=p_table_id for update;
 if not found or not v_table.occupied then raise exception 'Table is not occupied'; end if;
 if v_table.cleaning_needed then raise exception 'Cleaning workflow already started'; end if;
 -- Only served or cancelled orders can proceed. All served orders must be paid.
 for v_order in
  select o.id, o.status,
    coalesce((select sum(i.line_total_iqd) from public.gs_order_items i where i.order_id=o.id),0) as total,
    coalesce((select sum(p.amount_iqd) from public.gs_cash_payments p where p.order_id=o.id),0) as cash_paid
  from public.gs_orders o where o.is_motel=false
    and o.destination=v_table.table_number::text
  for update of o
 loop
  if v_order.status not in ('served','cancelled') then
    raise exception 'Active order prevents checkout'; end if;
  if v_order.status='served' and (v_order.total<=0 or v_order.cash_paid<>v_order.total) then
    raise exception 'Checkout requires verified full settlement for every served order'; end if;
 end loop;
 update public.gs_cafe_tables set cleaning_needed=true,
  guests_departed_at=now(),updated_at=now(),updated_by=auth.uid()
 where id=p_table_id;
 select t.id into v_cleaning from public.gs_table_service_tasks t
 where t.table_id=p_table_id and t.request_type='table_cleaning'
   and t.status not in ('completed','cancelled') order by t.id desc limit 1;
 if v_cleaning is null then
  insert into public.gs_table_service_tasks(table_id,request_type,created_by,priority,notes)
  values(p_table_id,'table_cleaning',auth.uid(),'urgent','Post-checkout cleaning; table not available')
  returning id into v_cleaning;
 end if;
 -- Shisha is a separate staff-confirmed physical collection flag, NOT inferred
 -- from an unreliable product name/barcode. Actual order linkage pending.
 if coalesce(p_shisha_collection_confirmed,false) then
  select t.id into v_shisha from public.gs_table_service_tasks t
  where t.table_id=p_table_id and t.request_type='shisha_pickup'
    and t.status not in ('completed','cancelled') order by t.id desc limit 1;
  if v_shisha is null then
   insert into public.gs_table_service_tasks(table_id,request_type,created_by,priority,notes)
   values(p_table_id,'shisha_pickup',auth.uid(),'urgent','Staff-confirmed shisha collection after departure')
   returning id into v_shisha;
  end if;
 end if;
 return query select v_cleaning,v_shisha;
end; $$;
revoke all on function public.gs_mark_table_departed_for_cleaning(bigint,boolean) from public,anon;
grant execute on function public.gs_mark_table_departed_for_cleaning(bigint,boolean) to authenticated;

-- Block legacy table-release RPC from clearing tables with pending cleaning.
-- Preserve original order/mode guards from migration 018.
create or replace function public.gs_update_cafe_table(
 p_table_number integer,p_occupied boolean,p_guests integer,p_tourism boolean
) returns void language plpgsql security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Permission denied'; end if;
 if p_occupied is null or p_tourism is null then raise exception 'Missing table state'; end if;
 select * into v_table from public.gs_cafe_tables where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 if p_occupied and (p_guests is null or p_guests<1 or p_guests>v_table.capacity) then
  raise exception 'Guest count exceeds table capacity'; end if;
 if v_table.cleaning_needed and not p_occupied then
  raise exception 'Cleaning required: use authorized cleaning release workflow'; end if;
 if v_table.cleaning_needed and p_occupied and not v_table.occupied then
  raise exception 'Cannot occupy table awaiting cleaning'; end if;
 if v_table.occupied and (not p_occupied or p_tourism is distinct from v_table.tourism_mode)
 and exists(select 1 from public.gs_orders where is_motel=false
  and destination=p_table_number::text and status in ('new','preparing','ready')) then
  raise exception 'Complete or cancel active orders first'; end if;
 update public.gs_cafe_tables set occupied=p_occupied,
  guests=case when p_occupied then p_guests else 0 end,
  tourism_mode=case when p_occupied then p_tourism else false end,
  updated_at=now(),updated_by=auth.uid() where id=v_table.id;
end; $$;

-- No release RPC in this upgrade: cleaning completion and independent
-- shisha pickup verification are prerequisites for the next stage.
