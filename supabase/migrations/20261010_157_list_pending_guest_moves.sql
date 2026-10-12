-- Upgrade 157: scoped read-only guest move queue for the Tables interface.
-- Does not grant direct access to private requests or execution audit tables.
create or replace function public.gs_list_pending_guest_moves()
returns table (
 request_id bigint, source_table_number integer, destination_table_number integer,
 moving_guests integer, move_bill boolean, reason text, requested_at timestamptz
) language plpgsql security definer set search_path='' stable as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Guest movement review denied';
 end if;
 return query
 select r.id, st.table_number, dt.table_number,
  r.moving_guests, r.move_bill, r.reason, r.requested_at
 from public.gs_table_guest_move_requests r
 join public.gs_table_visits sv on sv.id=r.source_visit_id
 join public.gs_table_visits dv on dv.id=r.destination_visit_id
 join public.gs_cafe_tables st on st.id=sv.table_id
 join public.gs_cafe_tables dt on dt.id=dv.table_id
 where r.status='pending'
 order by r.requested_at asc, r.id asc limit 100;
end; $$;
revoke all on function public.gs_list_pending_guest_moves() from public,anon;
grant execute on function public.gs_list_pending_guest_moves() to authenticated;
