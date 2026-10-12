-- Upgrade 152: approved reservation check-in bound to a single table visit.
-- Additive migration; deploy to staging first. No financial checkout behavior changes.
create table if not exists public.gs_reservation_visit_checkins (
 reservation_id uuid primary key references public.gs_public_reservation_requests(id),
 visit_id bigint not null unique references public.gs_table_visits(id),
 table_id bigint not null references public.gs_cafe_tables(id),
 checked_in_by uuid not null references auth.users(id),
 checked_in_at timestamptz not null default now()
);
alter table public.gs_reservation_visit_checkins enable row level security;
revoke all on public.gs_reservation_visit_checkins from public,anon,authenticated;

create or replace function public.gs_check_in_cafe_reservation(p_reservation_id uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare
 v_res public.gs_public_reservation_requests%rowtype;
 v_mapping public.gs_reservable_tables%rowtype;
 v_table public.gs_cafe_tables%rowtype;
 v_existing bigint;
 v_visit_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Reservation check-in permission denied';
 end if;
 if p_reservation_id is null then raise exception 'Reservation is required'; end if;
 -- Same advisory lock as reservation approval and walk-in seating.
 perform pg_advisory_xact_lock(721903,1);
 select * into v_res from public.gs_public_reservation_requests
  where id=p_reservation_id for update;
 if not found or v_res.status<>'approved' or v_res.assigned_table_id is null then
  raise exception 'Approved reservation required';
 end if;
 select visit_id into v_existing from public.gs_reservation_visit_checkins
  where reservation_id=p_reservation_id;
 if found then
  -- Retried request must not create a second visit.
  return v_existing;
 end if;
 if now()<v_res.requested_at-interval '30 minutes'
  or now()>=v_res.requested_at+make_interval(mins=>v_res.duration_minutes) then
  raise exception 'Reservation is outside its check-in window';
 end if;
 select * into v_mapping from public.gs_reservable_tables
  where id=v_res.assigned_table_id;
 if not found or not v_mapping.enabled or v_mapping.table_label !~ '^[0-9]+$' then
  raise exception 'Reservation table mapping is invalid';
 end if;
 -- Require a unique numeric mapping, not merely a matching display label.
 if (select count(*) from public.gs_reservable_tables
     where table_label ~ '^[0-9]+$'
       and table_label::bigint=v_mapping.table_label::bigint)<>1 then
  raise exception 'Ambiguous reservation table mapping';
 end if;
 select * into v_table from public.gs_cafe_tables
  where table_number=v_mapping.table_label::integer for update;
 if not found then raise exception 'Reservation table not configured'; end if;
 if v_res.party_size>v_mapping.seats or v_res.party_size>v_table.capacity
   or v_res.party_size<1 or v_res.party_size>50 then
  raise exception 'Reservation exceeds table capacity';
 end if;
 if v_table.occupied or coalesce(v_table.cleaning_needed,false)
  or exists(select 1 from public.gs_table_visits
    where table_id=v_table.id and status<>'closed') then
  raise exception 'Reserved table is occupied or requires cleaning';
 end if;
 if exists(select 1 from public.gs_public_reservation_requests r
  join public.gs_reservable_tables rt on rt.id=r.assigned_table_id
  where r.id<>v_res.id and r.status='approved'
   and rt.table_label=v_mapping.table_label
   and now()>=r.requested_at
   and now()<r.requested_at+make_interval(mins=>r.duration_minutes)) then
  raise exception 'Another approved reservation holds the table';
 end if;
 insert into public.gs_table_visits(table_id,opened_by,guest_count,tourism_mode)
 values(v_table.id,auth.uid(),v_res.party_size,false)
 returning id into v_visit_id;
 update public.gs_cafe_tables set occupied=true,guests=v_res.party_size,
  tourism_mode=false,updated_at=now(),updated_by=auth.uid()
 where id=v_table.id;
 insert into public.gs_reservation_visit_checkins(
  reservation_id,visit_id,table_id,checked_in_by)
 values(p_reservation_id,v_visit_id,v_table.id,auth.uid());
 return v_visit_id;
end; $$;
revoke all on function public.gs_check_in_cafe_reservation(uuid) from public,anon;
grant execute on function public.gs_check_in_cafe_reservation(uuid) to authenticated;
