-- Upgrade 290: staff-only table availability for event requests.
-- Read-only preview; approval must recheck under locking.
create or replace function public.gs_staff_event_table_options(
 p_start timestamptz,p_end timestamptz,p_guests integer)
returns table(table_id uuid,table_label text,seats integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized' using errcode='42501'; end if;
 if p_start is null or p_end is null or p_start<=now()
 or p_start>now()+interval '365 days' or p_end<=p_start
 or p_end>p_start+interval '24 hours' or p_guests not between 1 and 1000
 then raise exception 'Invalid event time or guest count'; end if;
 return query
 select t.id,t.table_label,t.seats
 from public.gs_reservable_tables t
 where t.enabled and t.seats>=p_guests
 and not exists (
  select 1 from public.gs_event_reservations e
  where e.requested_table_id=t.id and e.status='approved'
  and e.event_start<p_end and e.event_end>p_start)
 and not exists (
  select 1 from public.gs_public_reservation_requests r
  where r.assigned_table_id=t.id and r.status='approved'
  and r.requested_at<p_end
  and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
 order by t.seats,t.table_label limit 100;
end $$;
revoke all on function public.gs_staff_event_table_options(timestamptz,timestamptz,integer) from public,anon;
grant execute on function public.gs_staff_event_table_options(timestamptz,timestamptz,integer) to authenticated;
