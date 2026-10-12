-- DRAFT: guarded table release following post-checkout cleaning.
-- Depends on migrations 039 and 045. NOT deployed or runtime verified.
-- This function does not settle bills or complete service tasks.
create or replace function public.gs_release_cleaned_cafe_table(p_table_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit')
    or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Table release permission denied';
 end if;
 select * into v_table from public.gs_cafe_tables where id=p_table_id for update;
 if not found then raise exception 'Table not found'; end if;
 if not v_table.occupied or not v_table.cleaning_needed
    or v_table.guests_departed_at is null then
  raise exception 'Table must be departed and awaiting cleaning';
 end if;
 if not exists (
  select 1 from public.gs_table_service_tasks t
  where t.table_id=p_table_id and t.request_type='table_cleaning'
    and t.created_at>=v_table.guests_departed_at
    and t.status='completed'
 ) then raise exception 'Cleaning task must be completed'; end if;
 if exists (
  select 1 from public.gs_table_service_tasks t
  where t.table_id=p_table_id and t.request_type in ('table_cleaning','shisha_pickup')
    and t.status not in ('completed','cancelled')
 ) then raise exception 'Cleaning or shisha pickup still outstanding'; end if;
 -- Require confirmed shisha pickup, not cancellation, for tasks generated
 -- during this checkout. Historical cancelled tasks do not satisfy pickup.
 if exists (
  select 1 from public.gs_table_service_tasks t
  where t.table_id=p_table_id and t.request_type='shisha_pickup'
    and t.created_at>=v_table.guests_departed_at and t.status<>'completed'
 ) then raise exception 'Shisha pickup has not been completed'; end if;
 if exists (
  select 1 from public.gs_orders o
  where o.is_motel=false and o.destination=v_table.table_number::text
    and o.status in ('new','preparing','ready')
 ) then raise exception 'Active orders prevent table release'; end if;
 -- Re-check settlement, mirroring cash-only gate from 045. Noncash
 -- transactions cannot be treated as confirmed by this draft.
 if exists (
  select 1 from public.gs_orders o
  where o.is_motel=false and o.destination=v_table.table_number::text
   and o.status='served' and (
    coalesce((select sum(i.line_total_iqd) from public.gs_order_items i
      where i.order_id=o.id),0)<=0
    or coalesce((select sum(i.line_total_iqd) from public.gs_order_items i
      where i.order_id=o.id),0)
       <>coalesce((select sum(p.amount_iqd) from public.gs_cash_payments p
      where p.order_id=o.id),0)
   )
 ) then raise exception 'Orders are not fully cash-settled'; end if;
 update public.gs_cafe_tables set occupied=false,guests=0,
  tourism_mode=false,cleaning_needed=false,guests_departed_at=null,
  updated_at=now(),updated_by=auth.uid()
 where id=p_table_id;
end; $$;
revoke all on function public.gs_release_cleaned_cafe_table(bigint) from public,anon;
grant execute on function public.gs_release_cleaned_cafe_table(bigint) to authenticated;

-- TODO before production: immutable visit/session IDs, payment ledger covering
-- verified card/credit/online, table-level locking of all task mutations,
-- audited release event, and an authorization-safe UI confirmation.
