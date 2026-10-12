-- Upgrade 1189: explicitly assigned employees and station supervisors.
-- Existing station RPCs are renamed and their direct execution is revoked;
-- compatibility wrappers enforce station scope before calling the original logic.
create table if not exists public.gs_cafe_station_employee_assignments (
  station_key text not null references public.gs_cafe_preparation_stations(station_key),
  employee_id uuid not null references auth.users(id),
  assigned_by uuid references auth.users(id),
  assigned_at timestamptz not null default transaction_timestamp(),
  active boolean not null default true,
  primary key (station_key, employee_id)
);
create table if not exists public.gs_cafe_station_supervisors (
  employee_id uuid primary key references auth.users(id),
  assigned_by uuid references auth.users(id),
  assigned_at timestamptz not null default transaction_timestamp(),
  active boolean not null default true
);
alter table public.gs_cafe_station_employee_assignments enable row level security;
alter table public.gs_cafe_station_supervisors enable row level security;
revoke all on public.gs_cafe_station_employee_assignments,public.gs_cafe_station_supervisors from public,anon,authenticated;

create or replace function public.gs_can_work_station(p_station_key text)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and public.gs_can_access('kitchen','can_edit') and (
  exists(select 1 from public.gs_cafe_station_employee_assignments a
    where a.employee_id=auth.uid() and a.station_key=p_station_key and a.active)
  or exists(select 1 from public.gs_cafe_station_supervisors s
    where s.employee_id=auth.uid() and s.active)
 );
$$;
revoke all on function public.gs_can_work_station(text) from public,anon;
grant execute on function public.gs_can_work_station(text) to authenticated;

create or replace function public.gs_assign_station_employee(
 p_station_key text,p_employee_id uuid,p_active boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
   or not exists(select 1 from public.gs_cafe_station_supervisors s
                 where s.employee_id=auth.uid() and s.active) then
   raise exception 'Station supervisor authorization required'; end if;
 if p_station_key is null or p_employee_id is null or p_active is null or
   not exists(select 1 from public.gs_cafe_preparation_stations
              where station_key=p_station_key and enabled) then
   raise exception 'Valid active station and employee required'; end if;
 insert into public.gs_cafe_station_employee_assignments
   (station_key,employee_id,assigned_by,active)
 values(p_station_key,p_employee_id,auth.uid(),p_active)
 on conflict(station_key,employee_id) do update
   set active=excluded.active,assigned_by=excluded.assigned_by,
       assigned_at=transaction_timestamp();
end;
$$;
revoke all on function public.gs_assign_station_employee(text,uuid,boolean) from public,anon;
grant execute on function public.gs_assign_station_employee(text,uuid,boolean) to authenticated;
-- Bootstrap the first supervisor using a trusted database administrator only:
-- INSERT INTO public.gs_cafe_station_supervisors(employee_id,active) VALUES ('<auth-user-uuid>',true);

alter function public.gs_accept_station_preparation(bigint,integer)
 rename to gs_accept_station_preparation_legacy_1188;
revoke all on function public.gs_accept_station_preparation_legacy_1188(bigint,integer) from public,anon,authenticated;
create function public.gs_accept_station_preparation(p_ticket_id bigint,p_minutes integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text;
begin
 select station_key into v_station from public.gs_cafe_order_station_tickets where id=p_ticket_id;
 if v_station is null or not public.gs_can_work_station(v_station) then
  raise exception 'Not assigned to this preparation station'; end if;
 perform public.gs_accept_station_preparation_legacy_1188(p_ticket_id,p_minutes);
end;
$$;
revoke all on function public.gs_accept_station_preparation(bigint,integer) from public,anon;
grant execute on function public.gs_accept_station_preparation(bigint,integer) to authenticated;

alter function public.gs_complete_station_preparation(bigint)
 rename to gs_complete_station_preparation_legacy_1188;
revoke all on function public.gs_complete_station_preparation_legacy_1188(bigint) from public,anon,authenticated;
create function public.gs_complete_station_preparation(p_ticket_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text;
begin
 select station_key into v_station from public.gs_cafe_order_station_tickets where id=p_ticket_id;
 if v_station is null or not public.gs_can_work_station(v_station) then
  raise exception 'Not assigned to this preparation station'; end if;
 perform public.gs_complete_station_preparation_legacy_1188(p_ticket_id);
end;
$$;
revoke all on function public.gs_complete_station_preparation(bigint) from public,anon;
grant execute on function public.gs_complete_station_preparation(bigint) to authenticated;

alter function public.gs_record_station_handover(bigint,text)
 rename to gs_record_station_handover_legacy_1188;
revoke all on function public.gs_record_station_handover_legacy_1188(bigint,text) from public,anon,authenticated;
create function public.gs_record_station_handover(p_ticket_id bigint,p_action text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_station text;
begin
 select station_key into v_station from public.gs_cafe_order_station_tickets where id=p_ticket_id;
 if v_station is null or not public.gs_can_work_station(v_station) then
  raise exception 'Not assigned to this preparation station'; end if;
 perform public.gs_record_station_handover_legacy_1188(p_ticket_id,p_action);
end;
$$;
revoke all on function public.gs_record_station_handover(bigint,text) from public,anon;
grant execute on function public.gs_record_station_handover(bigint,text) to authenticated;

-- Return only tickets assigned to the employee (supervisors see all).
alter function public.gs_kitchen_station_preparation_queue()
 rename to gs_kitchen_station_preparation_queue_legacy_1188;
revoke all on function public.gs_kitchen_station_preparation_queue_legacy_1188() from public,anon,authenticated;
create function public.gs_kitchen_station_preparation_queue()
returns table(ticket_id bigint,order_id bigint,station_key text,station_name text,
 preparation_state text,accepted_at timestamptz,estimated_minutes integer,
 estimated_ready_at timestamptz,accepted_by uuid,ready_at timestamptz,
 item_count bigint,item_quantity bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 return query select q.* from public.gs_kitchen_station_preparation_queue_legacy_1188() q
 where exists(select 1 from public.gs_cafe_station_employee_assignments a
   where a.station_key=q.station_key and a.employee_id=auth.uid() and a.active)
 or exists(select 1 from public.gs_cafe_station_supervisors s
   where s.employee_id=auth.uid() and s.active);
end;
$$;
revoke all on function public.gs_kitchen_station_preparation_queue() from public,anon;
grant execute on function public.gs_kitchen_station_preparation_queue() to authenticated;
