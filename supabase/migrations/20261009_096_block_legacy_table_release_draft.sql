-- Upgrade 96: prevent legacy table state RPC from bypassing settlement.
-- Prior gs_update_cafe_table permitted occupied=false when kitchen orders
-- were finished, without verifying payment, cleaning or active visit closure.
-- This override blocks release until a dedicated authoritative workflow exists.
create or replace function public.gs_update_cafe_table(
 p_table_number integer, p_occupied boolean, p_guests integer, p_tourism boolean
) returns void language plpgsql security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Permission denied';
 end if;
 if p_table_number is null or p_occupied is null or p_tourism is null then
  raise exception 'Missing table state';
 end if;
 select * into v_table from public.gs_cafe_tables
  where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 -- Neither this legacy RPC nor a guessed paid balance may release a table.
 if not p_occupied then
  raise exception 'Legacy table release disabled: use verified visit checkout workflow';
 end if;
 -- Opening a new visit must use gs_open_cafe_table_visit, which creates
 -- the visit record and updates the table in one transaction.
 if not v_table.occupied then
  raise exception 'Use authorized open-visit workflow to occupy a table';
 end if;
 if v_table.cleaning_needed or v_table.guests_departed_at is not null then
  raise exception 'Table checkout/cleaning already in progress';
 end if;
 if p_guests is null or p_guests<1 or p_guests>v_table.capacity then
  raise exception 'Guest count exceeds table capacity';
 end if;
 if not exists (select 1 from public.gs_table_visits v
   where v.table_id=v_table.id and v.status='active') then
  raise exception 'Occupied table lacks an active visit; reconcile legacy state';
 end if;
 if p_tourism is distinct from v_table.tourism_mode and exists (
  select 1 from public.gs_orders o where o.table_visit_id in (
   select v.id from public.gs_table_visits v
   where v.table_id=v_table.id and v.status='active')
  and o.status<>'cancelled'
 ) then raise exception 'Cannot change pricing mode after orders exist in visit'; end if;
 update public.gs_cafe_tables set guests=p_guests,tourism_mode=p_tourism,
  updated_at=now(),updated_by=auth.uid() where id=v_table.id;
end; $$;
revoke all on function public.gs_update_cafe_table(integer,boolean,integer,boolean)
 from public,anon;
grant execute on function public.gs_update_cafe_table(integer,boolean,integer,boolean)
 to authenticated;
-- Does not implement departure, cleaning completion, payment or table release.
