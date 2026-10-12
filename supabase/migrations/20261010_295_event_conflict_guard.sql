-- Upgrade 295: serialized conflict protection for event and ordinary bookings.
create or replace function public.gs_event_scope_approval_guard()
returns trigger language plpgsql set search_path='' as $$
declare v_tables uuid[]; v_seats integer; v_count integer;
begin
 if new.status='approved' then
  perform pg_advisory_xact_lock(721903,1);
  if new.event_start<=now() or new.event_end<=new.event_start then raise exception 'Invalid event time'; end if;
  if new.venue_scope='whole_venue' then
   select array_agg(id),coalesce(sum(seats),0),count(*) into v_tables,v_seats,v_count from public.gs_reservable_tables where enabled;
  else
   select array_agg(table_id) into v_tables from public.gs_event_requested_tables where event_id=new.id;
   if v_tables is null and new.requested_table_id is not null then v_tables:=array[new.requested_table_id]; end if;
   select coalesce(sum(seats),0),count(*) into v_seats,v_count from public.gs_reservable_tables where enabled and id=any(v_tables);
  end if;
  if v_tables is null or v_count<>cardinality(v_tables) or v_seats<new.guest_count then raise exception 'Insufficient or unavailable tables'; end if;
  if exists(select 1 from public.gs_public_reservation_requests r where r.status='approved' and r.assigned_table_id=any(v_tables) and r.requested_at<new.event_end and r.requested_at+make_interval(mins=>r.duration_minutes)>new.event_start)
  or exists(select 1 from public.gs_event_reservations e where e.id<>new.id and e.status='approved' and e.event_start<new.event_end and e.event_end>new.event_start and (e.venue_scope='whole_venue' or new.venue_scope='whole_venue' or e.requested_table_id=any(v_tables) or exists(select 1 from public.gs_event_requested_tables t where t.event_id=e.id and t.table_id=any(v_tables)))) then raise exception 'Event reservation conflict'; end if;
 end if;
 return new;
end $$;
drop trigger if exists gs_event_scope_approval_guard_trigger on public.gs_event_reservations;
create trigger gs_event_scope_approval_guard_trigger before insert or update on public.gs_event_reservations for each row execute function public.gs_event_scope_approval_guard();

create or replace function public.gs_ordinary_event_conflict_guard()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.status='approved' and new.assigned_table_id is not null then
  perform pg_advisory_xact_lock(721903,1);
  if exists(select 1 from public.gs_event_reservations e where e.status='approved' and e.event_start<new.requested_at+make_interval(mins=>new.duration_minutes) and e.event_end>new.requested_at and (e.venue_scope='whole_venue' or e.requested_table_id=new.assigned_table_id or exists(select 1 from public.gs_event_requested_tables t where t.event_id=e.id and t.table_id=new.assigned_table_id))) then raise exception 'Table reserved for an event'; end if;
 end if;
 return new;
end $$;
drop trigger if exists gs_ordinary_event_conflict_trigger on public.gs_public_reservation_requests;
create trigger gs_ordinary_event_conflict_trigger before insert or update on public.gs_public_reservation_requests for each row execute function public.gs_ordinary_event_conflict_guard();

create or replace function public.gs_approved_event_tables_guard()
returns trigger language plpgsql set search_path='' as $$
begin
 if exists(select 1 from public.gs_event_reservations where id=coalesce(new.event_id,old.event_id) and status='approved') then raise exception 'Cannot change approved event tables'; end if;
 return coalesce(new,old);
end $$;
drop trigger if exists gs_approved_event_tables_trigger on public.gs_event_requested_tables;
create trigger gs_approved_event_tables_trigger before insert or update or delete on public.gs_event_requested_tables for each row execute function public.gs_approved_event_tables_guard();
