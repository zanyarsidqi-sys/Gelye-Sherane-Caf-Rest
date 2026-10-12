-- Section 02 Upgrade 154: permission-scoped reservation cancellation queue.
-- Cancellation itself remains handled by the existing audited gs_cancel_reservation(uuid).
create or replace function public.gs_list_cancellable_cafe_reservations()
returns table(reservation_id uuid, customer_name text, party_size integer,
 requested_at timestamptz, table_label text, status text)
language plpgsql security definer set search_path='' as $$
begin
 -- Match the existing cancellation RPC permission, not merely table view access.
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Reservation cancellation list permission denied';
 end if;
 return query
 select r.id,r.customer_name,r.party_size,r.requested_at,
  t.table_label,r.status
 from public.gs_public_reservation_requests r
 left join public.gs_reservable_tables t on t.id=r.assigned_table_id
 left join public.gs_reservation_visit_checkins c on c.reservation_id=r.id
 where r.status in ('pending','approved')
   and c.reservation_id is null
 order by r.requested_at desc limit 100;
end; $$;
revoke all on function public.gs_list_cancellable_cafe_reservations() from public,anon;
grant execute on function public.gs_list_cancellable_cafe_reservations() to authenticated;
