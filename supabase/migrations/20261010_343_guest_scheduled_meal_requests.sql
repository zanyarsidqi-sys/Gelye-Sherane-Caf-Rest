-- Guest-initiated scheduled meals: room QR + temporary reception-issued access code.
-- This is a request, never an automatically approved charge or kitchen ticket.
alter table public.gs_motel_scheduled_meals alter column created_by drop not null;
alter table public.gs_motel_scheduled_meals add column if not exists guest_session_id uuid references public.gs_motel_guest_stay_sessions(id);
create index if not exists gs_motel_meals_guest_session_idx on public.gs_motel_scheduled_meals(guest_session_id,created_at desc);
create or replace function public.gs_public_request_motel_scheduled_meal(
 p_room_token text,p_access_token text,p_description text,p_requested_for timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_room uuid; v_session uuid; v_id uuid;
begin
 if length(trim(coalesce(p_description,''))) not between 3 and 500 then
  raise exception 'Meal description must be 3-500 characters'; end if;
 if p_requested_for is null or p_requested_for <= now()+interval '15 minutes'
    or p_requested_for > now()+interval '90 days' then
  raise exception 'Choose a delivery time 15 minutes to 90 days ahead'; end if;
 begin
  select r.id,s.id into v_room,v_session
  from public.gs_motel_room_qr r
  join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
  where r.public_token=p_room_token::uuid and s.access_token=p_access_token::uuid
    and r.is_active and s.revoked_at is null and s.expires_at>now();
 exception when invalid_text_representation then raise exception 'Invalid guest access'; end;
 if v_session is null then raise exception 'Invalid or expired guest access'; end if;
 if (select count(*) from public.gs_motel_scheduled_meals
     where guest_session_id=v_session and created_at>now()-interval '1 hour')>=5 then
  raise exception 'Too many meal requests; please contact reception'; end if;
 insert into public.gs_motel_scheduled_meals(room_id,meal_description,requested_for,guest_session_id,status)
 values(v_room,trim(p_description),p_requested_for,v_session,'requested') returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_public_request_motel_scheduled_meal(text,text,text,timestamptz) from public;
grant execute on function public.gs_public_request_motel_scheduled_meal(text,text,text,timestamptz) to anon,authenticated;
