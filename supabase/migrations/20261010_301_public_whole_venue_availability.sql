-- Upgrade 301: public read-only whole-venue availability, no customer data exposed.
-- This is advisory only; the submission and Admin approval transactions recheck.
create or replace function public.gs_public_event_whole_venue_available(
 p_start timestamptz,p_end timestamptz)
returns boolean language sql stable security definer set search_path='' as $$
 select case
  when p_start is null or p_end is null or p_start<=now()
   or p_start>now()+interval '365 days' or p_end<=p_start
   or p_end>p_start+interval '24 hours' then false
  when not exists(select 1 from public.gs_reservable_tables t where t.enabled) then false
  when exists(select 1 from public.gs_event_reservations e
    where e.status='approved' and e.event_start<p_end and e.event_end>p_start)
    then false
  when exists(select 1 from public.gs_public_reservation_requests r
    where r.status='approved' and r.requested_at<p_end
    and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
    then false
  else true end;
$$;
revoke all on function public.gs_public_event_whole_venue_available(timestamptz,timestamptz) from public;
grant execute on function public.gs_public_event_whole_venue_available(timestamptz,timestamptz) to anon,authenticated;
