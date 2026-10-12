-- Public read-only availability: no customer information exposed.
create or replace function public.gs_public_event_available_tables(
 p_start timestamptz,p_end timestamptz)
returns table(table_id uuid,table_label text,seats integer)
language sql stable security definer set search_path='' as $$
 select t.id,t.table_label,t.seats from public.gs_reservable_tables t
 where t.enabled
 and p_start>now() and p_start<=now()+interval '365 days'
 and p_end>p_start and p_end<=p_start+interval '24 hours'
 and not exists(select 1 from public.gs_event_reservations e
   where e.status='approved' and e.event_start<p_end and e.event_end>p_start
   and (e.venue_scope='whole_venue' or e.requested_table_id=t.id
    or exists(select 1 from public.gs_event_requested_tables x
      where x.event_id=e.id and x.table_id=t.id)))
 and not exists(select 1 from public.gs_public_reservation_requests r
   where r.status='approved' and r.assigned_table_id=t.id
   and r.requested_at<p_end
   and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
 order by t.table_label limit 100;
$$;
revoke all on function public.gs_public_event_available_tables(timestamptz,timestamptz) from public;
grant execute on function public.gs_public_event_available_tables(timestamptz,timestamptz) to anon,authenticated;
