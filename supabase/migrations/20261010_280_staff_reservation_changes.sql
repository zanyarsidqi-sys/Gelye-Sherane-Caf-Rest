-- Upgrade 280: authorized, serialized reservation transfers/reschedules and cancellations.
-- Keep the original reservation id and preserve a complete before/after audit record.
create table if not exists public.gs_reservation_change_audit (
 id uuid primary key default gen_random_uuid(),
 reservation_id uuid not null references public.gs_public_reservation_requests(id),
 actor uuid not null,
 action text not null check (action in ('reschedule','cancel')),
 before_state jsonb not null,
 after_state jsonb not null,
 reason text,
 changed_at timestamptz not null default now()
);
alter table public.gs_reservation_change_audit enable row level security;
revoke all on public.gs_reservation_change_audit from public,anon,authenticated;

create or replace function public.gs_staff_change_specific_reservation(
 p_reservation_id uuid, p_action text, p_table_id uuid default null,
 p_start timestamptz default null, p_duration integer default null,
 p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_old public.gs_public_reservation_requests%rowtype;
        v_new public.gs_public_reservation_requests%rowtype;
        v_start timestamptz; v_duration integer; v_table uuid;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized to modify reservations';
 end if;
 if p_action not in ('reschedule','cancel') or p_action is null or
    length(coalesce(p_reason,'')) > 500 then
  raise exception 'Invalid reservation change';
 end if;
 -- Match the same transaction-level lock used by upgrade 279 confirmations.
 perform pg_advisory_xact_lock(721903,1);
 select * into v_old from public.gs_public_reservation_requests
 where id=p_reservation_id for update;
 if not found or v_old.status not in ('pending','approved') then
  raise exception 'Reservation cannot be changed in its current state';
 end if;
 if p_action='cancel' then
  if nullif(trim(coalesce(p_reason,'')),'') is null then
   raise exception 'Cancellation reason required';
  end if;
  update public.gs_public_reservation_requests set status='cancelled'
  where id=p_reservation_id;
 else
  v_start:=coalesce(p_start,v_old.requested_at);
  v_duration:=coalesce(p_duration,v_old.duration_minutes);
  v_table:=coalesce(p_table_id,v_old.assigned_table_id,v_old.requested_table_id);
  if v_table is null or v_start is null or v_duration is null or
     v_start <= now() or v_start > now()+interval '90 days' or
     v_duration not between 30 and 360 then
   raise exception 'Invalid reservation time, table, or duration';
  end if;
  if not exists(select 1 from public.gs_reservable_tables t
    where t.id=v_table and t.enabled and t.seats>=v_old.party_size) or
   exists(select 1 from public.gs_public_reservation_requests r
    where r.id<>p_reservation_id and r.status='approved'
      and r.assigned_table_id=v_table
      and r.requested_at < v_start+make_interval(mins=>v_duration)
      and r.requested_at+make_interval(mins=>r.duration_minutes)>v_start) then
   raise exception 'Selected table is unavailable';
  end if;
  update public.gs_public_reservation_requests
   set requested_at=v_start,duration_minutes=v_duration,
       requested_table_id=v_table,
       assigned_table_id=case when status='approved' then v_table else null end
   where id=p_reservation_id;
 end if;
 select * into v_new from public.gs_public_reservation_requests where id=p_reservation_id;
 insert into public.gs_reservation_change_audit
 (reservation_id,actor,action,before_state,after_state,reason)
 values(p_reservation_id,auth.uid(),p_action,to_jsonb(v_old),to_jsonb(v_new),
 nullif(trim(coalesce(p_reason,'')),''));
 insert into public.gs_public_request_review_audit
 (request_type,request_id,old_status,new_status,actor)
 values('reservation',p_reservation_id,v_old.status,v_new.status,auth.uid());
end $$;
revoke all on function public.gs_staff_change_specific_reservation(uuid,text,uuid,timestamptz,integer,text) from public,anon;
grant execute on function public.gs_staff_change_specific_reservation(uuid,text,uuid,timestamptz,integer,text) to authenticated;
