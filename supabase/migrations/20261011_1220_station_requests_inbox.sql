-- Upgrade 1220: pricing questions are service notifications, never order-price edits.
-- The existing cashier request type is used for public pricing questions until
-- a dedicated public pricing request UI and validated request type are deployed.
-- Supervisor can configure cashier routing with gs_set_request_station_route_1219.
-- This migration adds station-scoped acknowledgment without exposing the alerts table.
create or replace function public.gs_seen_service_station_alert_1220(p_request_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen view permission required'; end if;
 update public.gs_cafe_service_request_station_alerts n
 set seen_at=coalesce(n.seen_at,now())
 where n.request_id=p_request_id and n.employee_id=auth.uid()
 and exists(select 1 from public.gs_cafe_station_employee_assignments a
   where a.station_key=n.station_key and a.employee_id=auth.uid() and a.active);
 if not found then raise exception 'Alert unavailable'; end if;
end $$;
revoke all on function public.gs_seen_service_station_alert_1220(uuid) from public,anon;
grant execute on function public.gs_seen_service_station_alert_1220(uuid) to authenticated;
