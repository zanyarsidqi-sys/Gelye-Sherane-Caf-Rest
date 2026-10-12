-- Upgrade 341: Staff-issued guest access sessions. A room QR alone never grants access.
-- Staff must verify a current reception check-in before issuing an access token.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.gs_motel_guest_stay_sessions (
 id uuid primary key default extensions.gen_random_uuid(),
 room_id uuid not null references public.gs_motel_room_qr(id),
 access_token uuid not null unique default extensions.gen_random_uuid(),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 issued_by uuid not null,
 issued_at timestamptz not null default now(),
 check (expires_at > issued_at)
);
alter table public.gs_motel_guest_stay_sessions enable row level security;
revoke all on public.gs_motel_guest_stay_sessions from public, anon, authenticated;
create or replace function public.gs_staff_issue_motel_guest_access(p_room_label text, p_hours integer default 24)
returns text language plpgsql security definer set search_path = '' as $$
declare v_room uuid; v_token uuid;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then
  raise exception 'Motel guest access permission denied';
 end if;
 if p_hours < 1 or p_hours > 168 then raise exception 'Invalid access duration'; end if;
 select id into v_room from public.gs_motel_room_qr
 where room_label = trim(p_room_label) and is_active;
 if v_room is null then raise exception 'Room not found'; end if;
 -- Revoke prior access when a new guest access is issued for the same room.
 update public.gs_motel_guest_stay_sessions set revoked_at=now()
 where room_id=v_room and revoked_at is null;
 insert into public.gs_motel_guest_stay_sessions(room_id,expires_at,issued_by)
 values(v_room,now() + make_interval(hours => p_hours),auth.uid())
 returning access_token into v_token;
 return v_token::text;
end; $$;
revoke all on function public.gs_staff_issue_motel_guest_access(text,integer) from public,anon;
grant execute on function public.gs_staff_issue_motel_guest_access(text,integer) to authenticated;
create or replace function public.gs_public_verify_motel_guest_access(p_room_token text,p_access_token text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_room uuid; v_access uuid;
begin
 begin v_room:=p_room_token::uuid; v_access:=p_access_token::uuid;
 exception when invalid_text_representation then return false; end;
 return exists (
  select 1 from public.gs_motel_guest_stay_sessions s
  join public.gs_motel_room_qr r on r.id=s.room_id
  where r.public_token=v_room and r.is_active
   and s.access_token=v_access and s.revoked_at is null and s.expires_at>now()
 );
end; $$;
revoke all on function public.gs_public_verify_motel_guest_access(text,text) from public;
grant execute on function public.gs_public_verify_motel_guest_access(text,text) to anon,authenticated;
create or replace function public.gs_staff_revoke_motel_guest_access(p_room_label text)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then
  raise exception 'Motel guest access permission denied';
 end if;
 update public.gs_motel_guest_stay_sessions s set revoked_at=now()
 from public.gs_motel_room_qr r where r.id=s.room_id
 and r.room_label=trim(p_room_label) and s.revoked_at is null;
 get diagnostics v_count = row_count;
 return v_count;
end; $$;
revoke all on function public.gs_staff_revoke_motel_guest_access(text) from public,anon;
grant execute on function public.gs_staff_revoke_motel_guest_access(text) to authenticated;
