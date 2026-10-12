-- Read-only Kitchen visibility for approved scheduled motel meals.
-- No room charge, kitchen order insertion, or status mutation is performed.
create or replace function public.gs_kitchen_list_motel_scheduled_meals()
returns table(id uuid, room_label text, room_name text, meal_description text, requested_for timestamptz, status text)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.gs_can_access('kitchen', 'can_view') then
    raise exception 'Kitchen view permission required';
  end if;
  return query
    select m.id, r.room_label, r.room_name, m.meal_description, m.requested_for, m.status
    from public.gs_motel_scheduled_meals m
    join public.gs_motel_room_qr r on r.id = m.room_id
    where m.status in ('confirmed','scheduled','preparing','ready','on_way')
    order by m.requested_for asc
    limit 200;
end; $$;
revoke all on function public.gs_kitchen_list_motel_scheduled_meals() from public, anon;
grant execute on function public.gs_kitchen_list_motel_scheduled_meals() to authenticated;
