-- Upgrade 334: permanent physical room QR identity. Not proof of occupancy or authorization.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.gs_motel_room_qr (
  id uuid primary key default extensions.gen_random_uuid(),
  room_label text not null unique check (length(trim(room_label)) between 1 and 100),
  public_token uuid not null unique default extensions.gen_random_uuid(),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);
alter table public.gs_motel_room_qr enable row level security;
revoke all on public.gs_motel_room_qr from public, anon, authenticated;
-- Room codes can be provisioned/rotated only by staff with motel edit access.
create or replace function public.gs_staff_provision_motel_room_qr(p_room_label text, p_rotate boolean default false)
returns table(room_label text, qr_token text)
language plpgsql security definer set search_path = '' as $$
declare v_row public.gs_motel_room_qr%rowtype; v_label text;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then
   raise exception 'Motel QR management permission denied';
 end if;
 v_label := trim(p_room_label);
 if v_label is null or length(v_label) < 1 or length(v_label) > 100 then
   raise exception 'Invalid room label';
 end if;
 insert into public.gs_motel_room_qr(room_label) values(v_label)
 on conflict (room_label) do nothing;
 if p_rotate then
   update public.gs_motel_room_qr t
   set public_token = extensions.gen_random_uuid(), rotated_at = now(), is_active = true
   where t.room_label = v_label;
 end if;
 select * into v_row from public.gs_motel_room_qr t where t.room_label = v_label;
 if not v_row.is_active then raise exception 'Room QR disabled'; end if;
 room_label := v_row.room_label;
 qr_token := v_row.public_token::text;
 return next;
end; $$;
revoke all on function public.gs_staff_provision_motel_room_qr(text,boolean) from public,anon;
grant execute on function public.gs_staff_provision_motel_room_qr(text,boolean) to authenticated;
-- Public lookup exposes only room label; no guest identity, booking, bill or payment data.
create or replace function public.gs_public_identify_motel_room_qr(p_token text)
returns table(room_label text, identification_status text)
language plpgsql security definer set search_path = '' as $$
declare v_token uuid;
begin
 begin v_token := p_token::uuid;
 exception when invalid_text_representation then return; end;
 return query select t.room_label, 'room_identified_not_guest_verified'::text
 from public.gs_motel_room_qr t where t.public_token = v_token and t.is_active;
end; $$;
revoke all on function public.gs_public_identify_motel_room_qr(text) from public;
grant execute on function public.gs_public_identify_motel_room_qr(text) to anon,authenticated;
