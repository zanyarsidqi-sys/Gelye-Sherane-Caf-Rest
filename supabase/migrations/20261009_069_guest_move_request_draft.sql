-- Upgrade 69 DRAFT: safe, auditable guest movement REQUESTS.
-- Requests do not move guests or bills; no implicit table release.
create table if not exists public.gs_table_guest_move_requests (
 id bigint generated always as identity primary key,
 request_key uuid not null unique,
 source_visit_id bigint not null references public.gs_table_visits(id),
 destination_visit_id bigint not null references public.gs_table_visits(id),
 moving_guests integer not null check (moving_guests>0),
 move_bill boolean not null default false,
 status text not null default 'pending' check(status in ('pending','cancelled','rejected','applied')),
 reason text not null check(length(reason) between 5 and 500),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 check(source_visit_id<>destination_visit_id)
);
create index if not exists gs_table_guest_moves_source_idx on public.gs_table_guest_move_requests(source_visit_id,status);
create index if not exists gs_table_guest_moves_dest_idx on public.gs_table_guest_move_requests(destination_visit_id,status);
alter table public.gs_table_guest_move_requests enable row level security;
revoke all on public.gs_table_guest_move_requests from public,anon,authenticated;

create or replace function public.gs_request_table_guest_move(
 p_source_visit_id bigint,p_destination_visit_id bigint,
 p_moving_guests integer,p_move_bill boolean,p_reason text,p_request_key uuid
) returns bigint language plpgsql security definer set search_path='' as $$
declare
 v_src public.gs_table_visits%rowtype;
 v_dst public.gs_table_visits%rowtype;
 v_src_table public.gs_cafe_tables%rowtype;
 v_dst_table public.gs_cafe_tables%rowtype;
 v_existing public.gs_table_guest_move_requests%rowtype;
 v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table guest movement permission denied'; end if;
 if p_source_visit_id is null or p_destination_visit_id is null
  or p_source_visit_id=p_destination_visit_id or p_request_key is null
  or p_moving_guests is null or p_moving_guests<=0
  or p_move_bill is null or p_reason is null
  or length(btrim(p_reason))<5 or length(p_reason)>500 then
  raise exception 'Invalid guest move request'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
 select * into v_existing from public.gs_table_guest_move_requests
  where request_key=p_request_key for update;
 if found then
  if v_existing.source_visit_id=p_source_visit_id
   and v_existing.destination_visit_id=p_destination_visit_id
   and v_existing.moving_guests=p_moving_guests
   and v_existing.move_bill=p_move_bill
   and v_existing.reason=btrim(p_reason) then return v_existing.id; end if;
  raise exception 'Request key reused with different details';
 end if;
 -- Deterministic visit and table lock ordering.
 perform 1 from public.gs_table_visits
  where id in (p_source_visit_id,p_destination_visit_id) order by id for update;
 select * into v_src from public.gs_table_visits
  where id=p_source_visit_id and status='active';
 select * into v_dst from public.gs_table_visits
  where id=p_destination_visit_id and status='active';
 if v_src.id is null or v_dst.id is null or v_src.table_id=v_dst.table_id then
  raise exception 'Two distinct active table visits required'; end if;
 perform 1 from public.gs_cafe_tables
  where id in (v_src.table_id,v_dst.table_id) order by id for update;
 select * into v_src_table from public.gs_cafe_tables where id=v_src.table_id;
 select * into v_dst_table from public.gs_cafe_tables where id=v_dst.table_id;
 if not v_src_table.occupied or not v_dst_table.occupied
  or coalesce(v_src_table.cleaning_needed,false)
  or coalesce(v_dst_table.cleaning_needed,false) then
  raise exception 'Both tables must be occupied and not cleaning'; end if;
 if v_src.guest_count<p_moving_guests or v_src_table.guests<p_moving_guests then
  raise exception 'Not enough guests at source'; end if;
 if v_dst.guest_count+p_moving_guests>v_dst_table.capacity
  or v_dst_table.guests+p_moving_guests>v_dst_table.capacity then
  raise exception 'Destination table capacity exceeded'; end if;
 -- Pending moves also need serialized capacity reservations at execution.
 if exists(select 1 from public.gs_table_guest_move_requests m
  where m.status='pending' and (m.source_visit_id in (p_source_visit_id,p_destination_visit_id)
   or m.destination_visit_id in (p_source_visit_id,p_destination_visit_id))) then
  raise exception 'Another guest move is pending for these tables'; end if;
 insert into public.gs_table_guest_move_requests(
  request_key,source_visit_id,destination_visit_id,moving_guests,move_bill,reason,requested_by)
 values(p_request_key,p_source_visit_id,p_destination_visit_id,p_moving_guests,
  p_move_bill,btrim(p_reason),auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_request_table_guest_move(bigint,bigint,integer,boolean,text,uuid) from public,anon;
grant execute on function public.gs_request_table_guest_move(bigint,bigint,integer,boolean,text,uuid) to authenticated;
-- No execution RPC until visit guest counts, table counts, active reservations,
-- bill transfer and source checkout are atomically reconciled.
