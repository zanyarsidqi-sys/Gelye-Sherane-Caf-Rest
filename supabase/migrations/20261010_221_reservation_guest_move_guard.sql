-- Upgrade 221: reservation-aware guest-count move preview and execution.
-- Only guest-count moves; no order, bill, payment, or reservation transfer.
-- Advisory previews are snapshots. Execution rechecks while holding the
-- same reservation lock used by reservation approval and table seating.
-- Upgrade 220: advisory guest-count move safety preview.
-- Does not execute guest moves, exchange tables, transfer orders or join bills.
-- Final execution still enforces atomic locks in gs_execute_guest_count_only_move.
create or replace function public.gs_preview_guest_move_safety(p_request_id bigint)
returns table(can_execute boolean, blockers text[], source_table integer,
 destination_table integer, source_guests integer, destination_guests integer,
 destination_capacity integer)
language plpgsql security definer set search_path='' stable as $$
declare r public.gs_table_guest_move_requests%rowtype;
 s public.gs_table_visits%rowtype; d public.gs_table_visits%rowtype;
 st public.gs_cafe_tables%rowtype; dt public.gs_cafe_tables%rowtype;
 problems text[] := array[]::text[];
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Guest move preview permission denied'; end if;
 if p_request_id is null then raise exception 'Request ID required'; end if;
 select * into r from public.gs_table_guest_move_requests where id=p_request_id;
 if not found then raise exception 'Guest move request not found'; end if;
 select * into s from public.gs_table_visits where id=r.source_visit_id;
 select * into d from public.gs_table_visits where id=r.destination_visit_id;
 select * into st from public.gs_cafe_tables where id=s.table_id;
 select * into dt from public.gs_cafe_tables where id=d.table_id;
 if r.status <> 'pending' then problems:=array_append(problems,'Request is no longer pending'); end if;
 if r.move_bill then problems:=array_append(problems,'Bill transfer requires separate financial approval'); end if;
 if s.id is null or d.id is null or s.status <> 'active' or d.status <> 'active'
   or s.table_id=d.table_id then
   problems:=array_append(problems,'Both visits must be active and distinct'); end if;
 if st.id is null or dt.id is null or not coalesce(st.occupied,false)
   or not coalesce(dt.occupied,false) or coalesce(st.cleaning_needed,false)
   or coalesce(dt.cleaning_needed,false) then
   problems:=array_append(problems,'Table unavailable or awaiting cleaning'); end if;
 if s.guest_count is distinct from st.guests or d.guest_count is distinct from dt.guests then
   problems:=array_append(problems,'Visit and table guest counts differ'); end if;
 if r.moving_guests is null or r.moving_guests <= 0
   or s.guest_count is null or s.guest_count <= r.moving_guests then
   problems:=array_append(problems,'Source must retain at least one guest'); end if;
 if dt.capacity is null or d.guest_count+r.moving_guests > dt.capacity then
   problems:=array_append(problems,'Destination does not have sufficient chairs'); end if;
 if dt.id is not null and exists (
   select 1 from public.gs_public_reservation_requests rr
   join public.gs_reservable_tables rt on rt.id=rr.assigned_table_id
   where rr.status='approved' and rt.table_label=dt.table_number::text
     and rr.requested_at < now()+interval '30 minutes'
     and rr.requested_at+make_interval(mins=>rr.duration_minutes)>now()
 ) then problems:=array_append(problems,'Destination has an approved reservation now or within 30 minutes'); end if;
 if exists(select 1 from public.gs_table_guest_move_requests m
   where m.id<>r.id and m.status='pending' and
   (m.source_visit_id in (r.source_visit_id,r.destination_visit_id)
    or m.destination_visit_id in (r.source_visit_id,r.destination_visit_id))) then
   problems:=array_append(problems,'Conflicting pending guest move'); end if;
 return query select cardinality(problems)=0,problems,st.table_number,dt.table_number,
   s.guest_count,d.guest_count,dt.capacity;
end $$;
revoke all on function public.gs_preview_guest_move_safety(bigint) from public,anon;
grant execute on function public.gs_preview_guest_move_safety(bigint) to authenticated;

create or replace function public.gs_execute_guest_count_only_move(p_request_id bigint)
returns boolean language plpgsql security definer set search_path='' as $$
declare
 r public.gs_table_guest_move_requests%rowtype;
 s public.gs_table_visits%rowtype;
 d public.gs_table_visits%rowtype;
 st public.gs_cafe_tables%rowtype;
 dt public.gs_cafe_tables%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table guest move execution denied'; end if;
 if p_request_id is null then raise exception 'Request required'; end if;
 -- Match reservation approval lock ordering before visit/table row locks.
 perform pg_advisory_xact_lock(721903,1);
 select * into r from public.gs_table_guest_move_requests where id=p_request_id for update;
 if not found then raise exception 'Guest move request not found'; end if;
 if r.status='applied' then
  if exists(select 1 from public.gs_table_guest_move_execution_audit where request_id=r.id)
  then return false; end if;
  raise exception 'Applied request has no execution audit';
 end if;
 if r.status<>'pending' then raise exception 'Only pending requests can execute'; end if;
 if r.move_bill then raise exception 'Bill-transfer requests require separate financial execution'; end if;
 if r.source_visit_id=r.destination_visit_id then raise exception 'Distinct visits required'; end if;
 perform 1 from public.gs_table_visits
  where id in(r.source_visit_id,r.destination_visit_id) order by id for update;
 select * into s from public.gs_table_visits where id=r.source_visit_id;
 select * into d from public.gs_table_visits where id=r.destination_visit_id;
 if s.id is null or d.id is null or s.status<>'active' or d.status<>'active'
   or s.table_id=d.table_id then raise exception 'Both visits must remain active and distinct'; end if;
 perform 1 from public.gs_cafe_tables where id in(s.table_id,d.table_id) order by id for update;
 select * into st from public.gs_cafe_tables where id=s.table_id;
 select * into dt from public.gs_cafe_tables where id=d.table_id;
 if not st.occupied or not dt.occupied or coalesce(st.cleaning_needed,false)
  or coalesce(dt.cleaning_needed,false) then raise exception 'Table state changed'; end if;
 if s.guest_count<>st.guests or d.guest_count<>dt.guests then
  raise exception 'Table and visit guest counts disagree'; end if;
 if r.moving_guests<=0 or s.guest_count<=r.moving_guests then
  raise exception 'At least one guest must remain at source; use full checkout for last guest'; end if;
 if d.guest_count+r.moving_guests>dt.capacity then
  raise exception 'Destination capacity exceeded'; end if;
 -- Reject guest moves into a table held by an approved reservation now or
 -- within the next 30 minutes. Never silently alter the reservation or bills.
 if exists (
   select 1 from public.gs_public_reservation_requests rr
   join public.gs_reservable_tables rt on rt.id=rr.assigned_table_id
   where rr.status='approved' and rt.table_label=dt.table_number::text
     and rr.requested_at < now()+interval '30 minutes'
     and rr.requested_at+make_interval(mins=>rr.duration_minutes)>now()
 ) then raise exception 'Destination has an approved reservation now or within 30 minutes'; end if;

 if exists(select 1 from public.gs_table_guest_move_requests m
  where m.id<>r.id and m.status='pending' and
  (m.source_visit_id in(r.source_visit_id,r.destination_visit_id)
   or m.destination_visit_id in(r.source_visit_id,r.destination_visit_id))) then
  raise exception 'Another conflicting move remains pending'; end if;
 -- Keep original visits, orders, pricing snapshots, reservations and payments intact.
 update public.gs_table_visits set guest_count=guest_count-r.moving_guests where id=s.id;
 update public.gs_table_visits set guest_count=guest_count+r.moving_guests where id=d.id;
 update public.gs_cafe_tables set guests=guests-r.moving_guests,
  updated_at=now(),updated_by=auth.uid() where id=st.id;
 update public.gs_cafe_tables set guests=guests+r.moving_guests,
  updated_at=now(),updated_by=auth.uid() where id=dt.id;
 insert into public.gs_table_guest_move_execution_audit(
  request_id,source_visit_id,destination_visit_id,moving_guests,
  source_guests_before,destination_guests_before,executed_by)
 values(r.id,s.id,d.id,r.moving_guests,s.guest_count,d.guest_count,auth.uid());
 update public.gs_table_guest_move_requests set status='applied' where id=r.id;
 return true;
end; $$;
revoke all on function public.gs_execute_guest_count_only_move(bigint) from public,anon;
grant execute on function public.gs_execute_guest_count_only_move(bigint) to authenticated;
