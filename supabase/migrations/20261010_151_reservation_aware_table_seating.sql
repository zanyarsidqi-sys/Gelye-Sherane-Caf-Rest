-- Upgrade 151: reservation-aware atomic table seating.
-- Apply only after reservation, table and visit migrations; stage-test first.
-- An approved reservation currently blocks walk-in seating for its entire window.
-- Staff must cancel/reassign that reservation through an audited workflow.
create or replace function public.gs_open_cafe_table_visit(
 p_table_number integer, p_guests integer, p_tourism boolean default false)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype; v_visit_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Not authorized to open table visits';
 end if;
 if p_tourism is null then raise exception 'Tourism mode is required'; end if;
 -- Serialize reservation approvals and seating across transactions. Lock order:
 -- reservation advisory lock first, then table row, matching reservation RPC.
 perform pg_advisory_xact_lock(721903,1);
 select * into v_table from public.gs_cafe_tables
 where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 if p_guests is null or p_guests < 1 or p_guests > v_table.capacity then
   raise exception 'Guest count exceeds table capacity'; end if;
 if v_table.occupied or coalesce(v_table.cleaning_needed,false) then
   raise exception 'Table is occupied or requires cleaning'; end if;
 if exists (select 1 from public.gs_table_visits v
   where v.table_id=v_table.id and v.status <> 'closed') then
   raise exception 'Table has an open visit'; end if;
 -- Reservation labels are a legacy integration contract: numeric table label.
 -- Fail closed if an active reservation holds this table.
 if exists (
  select 1 from public.gs_public_reservation_requests r
  join public.gs_reservable_tables rt on rt.id=r.assigned_table_id
  where r.status='approved' and rt.enabled
   and rt.table_label=p_table_number::text
   and now() >= r.requested_at
   and now() < r.requested_at + make_interval(mins=>r.duration_minutes)
 ) then raise exception 'Table is held for an approved reservation'; end if;
 -- Fail closed if an approved reservation maps to a disabled table too.
 if exists (
  select 1 from public.gs_public_reservation_requests r
  join public.gs_reservable_tables rt on rt.id=r.assigned_table_id
  where r.status='approved' and rt.table_label=p_table_number::text
   and now() >= r.requested_at
   and now() < r.requested_at + make_interval(mins=>r.duration_minutes)
 ) then raise exception 'Table has an active reservation'; end if;
 insert into public.gs_table_visits(table_id,opened_by,guest_count,tourism_mode)
 values(v_table.id,auth.uid(),p_guests,p_tourism) returning id into v_visit_id;
 update public.gs_cafe_tables set occupied=true,guests=p_guests,
  tourism_mode=p_tourism,updated_at=now(),updated_by=auth.uid()
 where id=v_table.id;
 return v_visit_id;
end; $$;
revoke all on function public.gs_open_cafe_table_visit(integer,integer,boolean) from public,anon;
grant execute on function public.gs_open_cafe_table_visit(integer,integer,boolean) to authenticated;
