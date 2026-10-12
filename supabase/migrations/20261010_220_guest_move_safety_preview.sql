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
