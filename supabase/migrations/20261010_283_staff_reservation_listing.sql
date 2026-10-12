-- Upgrade 283: authenticated staff reservation listing, with no anonymous access.
create or replace function public.gs_staff_specific_reservations(p_limit integer default 50)
returns table(id uuid, customer_name text, phone text, requested_at timestamptz,
 party_size integer, duration_minutes integer, status text, requested_table_id uuid,
 assigned_table_id uuid, notes text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized to view reservation management';
 end if;
 return query select r.id,r.customer_name,r.phone,r.requested_at,r.party_size,
 r.duration_minutes,r.status::text,r.requested_table_id,r.assigned_table_id,r.notes
 from public.gs_public_reservation_requests r
 where r.status in ('pending','approved')
 order by r.requested_at asc limit least(greatest(coalesce(p_limit,50),1),100);
end $$;
revoke all on function public.gs_staff_specific_reservations(integer) from public,anon;
grant execute on function public.gs_staff_specific_reservations(integer) to authenticated;
