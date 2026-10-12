-- Apply after migrations 001, 016 and 017.
-- Do not release a table while its kitchen orders are active.
create or replace function public.gs_update_cafe_table(
 p_table_number integer, p_occupied boolean, p_guests integer, p_tourism boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_capacity integer; v_was_occupied boolean; v_previous_tourism boolean;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Permission denied';
 end if;
 if p_occupied is null or p_tourism is null then raise exception 'Missing table state'; end if;
 select capacity, occupied, tourism_mode into v_capacity, v_was_occupied, v_previous_tourism
 from public.gs_cafe_tables where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 if p_occupied and (p_guests is null or p_guests < 1 or p_guests > v_capacity) then
   raise exception 'Guest count exceeds table capacity';
 end if;
 -- Both releasing and changing mode require all associated orders to finish.
 if v_was_occupied and (not p_occupied or p_tourism is distinct from v_previous_tourism)
 and exists (
   select 1 from public.gs_orders
   where is_motel=false and destination=p_table_number::text
   and status in ('new','preparing','ready')
 ) then
   raise exception 'Complete or cancel active table orders before releasing or changing pricing mode';
 end if;
 update public.gs_cafe_tables set occupied=p_occupied,
 guests=case when p_occupied then p_guests else 0 end,
 tourism_mode=case when p_occupied then p_tourism else false end,
 updated_at=now(), updated_by=auth.uid()
 where table_number=p_table_number;
end;$$;
revoke all on function public.gs_update_cafe_table(integer,boolean,integer,boolean) from public;
grant execute on function public.gs_update_cafe_table(integer,boolean,integer,boolean) to authenticated;
