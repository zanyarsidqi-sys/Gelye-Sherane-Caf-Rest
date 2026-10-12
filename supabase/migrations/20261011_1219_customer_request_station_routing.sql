-- Upgrade 1219: customer service requests are routed independently of preparation tickets.
-- Unmapped requests stay in the supervisor queue (station_key NULL).
create table if not exists public.gs_cafe_service_request_station_routes (
 call_type text primary key,
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
alter table public.gs_cafe_service_request_station_routes enable row level security;
revoke all on public.gs_cafe_service_request_station_routes from public,anon,authenticated;
alter table public.gs_customer_staff_calls add column if not exists routed_station_key text references public.gs_cafe_preparation_stations(station_key);
create index if not exists gs_staff_calls_station_status_idx on public.gs_customer_staff_calls(routed_station_key,status,requested_at);
create table if not exists public.gs_cafe_service_request_station_alerts (
 request_id uuid not null references public.gs_customer_staff_calls(id),
 employee_id uuid not null references auth.users(id),
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 created_at timestamptz not null default now(), seen_at timestamptz,
 primary key(request_id,employee_id)
);
alter table public.gs_cafe_service_request_station_alerts enable row level security;
revoke all on public.gs_cafe_service_request_station_alerts from public,anon,authenticated;

create or replace function public.gs_route_customer_request_1219()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_station text;
begin
 select r.station_key into v_station from public.gs_cafe_service_request_station_routes r
 join public.gs_cafe_preparation_stations s on s.station_key=r.station_key and s.enabled
 where r.call_type=new.call_type;
 update public.gs_customer_staff_calls set routed_station_key=v_station where id=new.id;
 if v_station is not null then
  insert into public.gs_cafe_service_request_station_alerts(request_id,employee_id,station_key)
  select new.id,a.employee_id,v_station from public.gs_cafe_station_employee_assignments a
  where a.station_key=v_station and a.active on conflict do nothing;
 end if;
 return new;
end $$;
drop trigger if exists gs_route_customer_request_1219 on public.gs_customer_staff_calls;
create trigger gs_route_customer_request_1219 after insert on public.gs_customer_staff_calls
for each row execute function public.gs_route_customer_request_1219();

create or replace function public.gs_set_request_station_route_1219(p_call_type text,p_station_key text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
    or not exists(select 1 from public.gs_cafe_station_supervisors where employee_id=auth.uid() and active)
 then raise exception 'Active station supervisor required'; end if;
 if p_call_type not in ('waiter','cashier','shisha','supervisor','any','specific_order','extra_chairs','long_wait','pick_dishes','clean_table')
 then raise exception 'Unsupported request type'; end if;
 if not exists(select 1 from public.gs_cafe_preparation_stations where station_key=p_station_key and enabled)
 then raise exception 'Station not active'; end if;
 insert into public.gs_cafe_service_request_station_routes(call_type,station_key,updated_by)
 values(p_call_type,p_station_key,auth.uid()) on conflict(call_type) do update
 set station_key=excluded.station_key,updated_by=excluded.updated_by,updated_at=now();
end $$;

create or replace function public.gs_my_service_station_requests_1219(p_limit integer default 100)
returns table(request_id uuid,table_id bigint,call_type text,note text,status text,station_key text,requested_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 return query select c.id,c.table_id,c.call_type,c.note,c.status,c.routed_station_key,c.requested_at
 from public.gs_customer_staff_calls c where
 (c.routed_station_key is not null and exists
  (select 1 from public.gs_cafe_station_employee_assignments a
   where a.station_key=c.routed_station_key and a.employee_id=auth.uid() and a.active))
 or (c.routed_station_key is null and exists
  (select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active))
 order by c.requested_at desc limit least(greatest(coalesce(p_limit,100),1),250);
end $$;

create or replace function public.gs_my_service_station_alerts_1219(p_limit integer default 100)
returns table(request_id uuid,station_key text,created_at timestamptz,seen_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select n.request_id,n.station_key,n.created_at,n.seen_at
 from public.gs_cafe_service_request_station_alerts n
 join public.gs_cafe_station_employee_assignments a on a.station_key=n.station_key and a.employee_id=auth.uid() and a.active
 where n.employee_id=auth.uid() order by n.created_at desc
 limit least(greatest(coalesce(p_limit,100),1),250);
end $$;
revoke all on function public.gs_route_customer_request_1219() from public,anon,authenticated;
revoke all on function public.gs_set_request_station_route_1219(text,text) from public,anon;
revoke all on function public.gs_my_service_station_requests_1219(integer) from public,anon;
revoke all on function public.gs_my_service_station_alerts_1219(integer) from public,anon;
grant execute on function public.gs_set_request_station_route_1219(text,text),
 public.gs_my_service_station_requests_1219(integer),public.gs_my_service_station_alerts_1219(integer) to authenticated;
