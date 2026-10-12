-- Phase 3: server-enforced reservation capacity and collision prevention.
-- Configure actual reservable tables before enabling approvals.
create table if not exists public.gs_reservable_tables (
 id uuid primary key default gen_random_uuid(),
 table_label text not null unique,
 seats integer not null check (seats between 1 and 100),
 enabled boolean not null default true
);
alter table public.gs_reservable_tables enable row level security;
revoke all on public.gs_reservable_tables from anon, authenticated;

alter table public.gs_public_reservation_requests
 add column if not exists assigned_table_id uuid references public.gs_reservable_tables(id),
 add column if not exists duration_minutes integer not null default 120 check (duration_minutes between 30 and 360);
create index if not exists gs_reservation_table_time_idx on public.gs_public_reservation_requests(assigned_table_id, requested_at) where status='approved';

-- Replace the prior review function so reservation approvals require a real table.
-- The transaction-scoped advisory lock serializes approvals, including concurrent staff actions.
create or replace function public.gs_staff_review_public_request(p_type text,p_id uuid,p_action text)
returns text language plpgsql security definer set search_path = '' as $$
declare old_state text; next_state text; requested timestamptz; party integer; duration integer; chosen uuid;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then raise exception 'Not authorized'; end if;
 if p_type='order' and p_action in ('accept','decline') then
  next_state:=case when p_action='accept' then 'accepted' else 'declined' end;
  select status into old_state from public.gs_public_order_requests where id=p_id for update;
  if old_state is distinct from 'pending' then raise exception 'Request no longer pending'; end if;
  update public.gs_public_order_requests set status=next_state where id=p_id;
 elsif p_type='reservation' and p_action in ('approve','decline') then
  next_state:=case when p_action='approve' then 'approved' else 'declined' end;
  perform pg_advisory_xact_lock(721903, 1);
  select status, requested_at, party_size, duration_minutes into old_state,requested,party,duration
   from public.gs_public_reservation_requests where id=p_id for update;
  if old_state is distinct from 'pending' then raise exception 'Request no longer pending'; end if;
  if p_action='approve' then
   if requested <= now() then raise exception 'Reservation time is in the past'; end if;
   select t.id into chosen from public.gs_reservable_tables t
    where t.enabled and t.seats >= party
    and not exists (
      select 1 from public.gs_public_reservation_requests r
      where r.status='approved' and r.assigned_table_id=t.id
      and r.requested_at < requested + make_interval(mins=>duration)
      and r.requested_at + make_interval(mins=>r.duration_minutes) > requested
    ) order by t.seats asc,t.table_label asc limit 1;
   if chosen is null then raise exception 'No available table for this reservation'; end if;
   update public.gs_public_reservation_requests set status='approved',assigned_table_id=chosen where id=p_id;
  else
   update public.gs_public_reservation_requests set status='declined' where id=p_id;
  end if;
 else raise exception 'Invalid review action'; end if;
 insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
 values(p_type,p_id,old_state,next_state,auth.uid());
 return next_state;
end $$;
revoke all on function public.gs_staff_review_public_request(text,uuid,text) from public;
grant execute on function public.gs_staff_review_public_request(text,uuid,text) to authenticated;

-- Staff-only table inventory management, with backend permission enforcement.
create or replace function public.gs_set_reservable_table(p_label text,p_seats integer,p_enabled boolean default true)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then raise exception 'Not authorized'; end if;
 if length(trim(coalesce(p_label,''))) not between 1 and 80 or p_seats not between 1 and 100 then raise exception 'Invalid table configuration'; end if;
 insert into public.gs_reservable_tables(table_label,seats,enabled) values(trim(p_label),p_seats,p_enabled)
 on conflict(table_label) do update set seats=excluded.seats,enabled=excluded.enabled
 returning id into result;
 return result;
end $$;
revoke all on function public.gs_set_reservable_table(text,integer,boolean) from public;
grant execute on function public.gs_set_reservable_table(text,integer,boolean) to authenticated;
