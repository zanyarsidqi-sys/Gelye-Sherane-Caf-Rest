-- Guest-scoped read-only status for scheduled motel meals.
-- A room QR by itself does not authorize private order history.
create or replace function public.gs_public_motel_meal_status(
 p_room_token text, p_access_token text)
returns table(meal_id uuid, meal_description text, requested_for timestamptz,
 status text, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_session uuid;
begin
 begin
  select s.id into v_session
  from public.gs_motel_room_qr r
  join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
  where r.public_token=p_room_token::uuid
    and s.access_token=p_access_token::uuid
    and r.is_active and s.revoked_at is null and s.expires_at>now();
 exception when invalid_text_representation then
  raise exception 'Invalid guest access';
 end;
 if v_session is null then raise exception 'Invalid or expired guest access'; end if;
 return query
 select m.id,m.meal_description,m.requested_for,m.status,m.created_at
 from public.gs_motel_scheduled_meals m
 where m.guest_session_id=v_session
 order by m.created_at desc limit 50;
end; $$;
revoke all on function public.gs_public_motel_meal_status(text,text) from public;
grant execute on function public.gs_public_motel_meal_status(text,text) to anon,authenticated;
