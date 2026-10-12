-- Section 02: permission-scoped, minimal reservation queue for staff check-in.
-- No direct SELECT access to private reservation records is granted.
create or replace function public.gs_list_approved_cafe_reservations()
returns table(reservation_id uuid, customer_name text, party_size integer,
 requested_at timestamptz, table_label text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Reservation list permission denied';
 end if;
 return query
 select r.id,r.customer_name,r.party_size,r.requested_at,t.table_label
 from public.gs_public_reservation_requests r
 join public.gs_reservable_tables t on t.id=r.assigned_table_id
 left join public.gs_reservation_visit_checkins c on c.reservation_id=r.id
 where r.status='approved' and c.reservation_id is null
  and now()>=r.requested_at-interval '30 minutes'
  and now()<r.requested_at+make_interval(mins=>r.duration_minutes)
 order by r.requested_at limit 100;
end; $$;
revoke all on function public.gs_list_approved_cafe_reservations() from public,anon;
grant execute on function public.gs_list_approved_cafe_reservations() to authenticated;
