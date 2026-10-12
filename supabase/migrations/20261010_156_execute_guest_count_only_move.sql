-- Upgrade 156: deliberately narrow, atomic guest-count-only move execution.
-- No order, bill, payment, reservation or visit ownership transfer.
-- Never execute a move_bill=true request through this RPC.
create table if not exists public.gs_table_guest_move_execution_audit (
 request_id bigint primary key references public.gs_table_guest_move_requests(id),
 source_visit_id bigint not null references public.gs_table_visits(id),
 destination_visit_id bigint not null references public.gs_table_visits(id),
 moving_guests integer not null check(moving_guests>0),
 source_guests_before integer not null,
 destination_guests_before integer not null,
 executed_by uuid not null references auth.users(id),
 executed_at timestamptz not null default now()
);
alter table public.gs_table_guest_move_execution_audit enable row level security;
revoke all on public.gs_table_guest_move_execution_audit from public,anon,authenticated;

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
