-- Upgrade 335: descriptive metadata on the existing QR room registry.
alter table public.gs_motel_room_qr
  add column if not exists room_name text,
  add column if not exists accommodation_type text not null default 'room';
update public.gs_motel_room_qr set room_name = room_label where room_name is null;
alter table public.gs_motel_room_qr alter column room_name set not null;
alter table public.gs_motel_room_qr drop constraint if exists gs_motel_room_qr_name_length;
alter table public.gs_motel_room_qr add constraint gs_motel_room_qr_name_length check (length(trim(room_name)) between 1 and 100);
alter table public.gs_motel_room_qr drop constraint if exists gs_motel_room_qr_accommodation_type_check;
alter table public.gs_motel_room_qr add constraint gs_motel_room_qr_accommodation_type_check check (accommodation_type in ('room','villa','chalet','cottage','suite','other'));
create or replace function public.gs_staff_save_motel_room(p_room_label text, p_room_name text, p_accommodation_type text)
returns table(saved_room_label text, saved_room_name text, saved_accommodation_type text)
language plpgsql security definer set search_path = '' as $$
declare v_label text := nullif(trim(p_room_label),''); v_name text := nullif(trim(p_room_name),''); v_type text := lower(trim(p_accommodation_type));
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then raise exception 'Motel edit permission denied'; end if;
 if v_label is null or length(v_label)>100 or v_name is null or length(v_name)>100 then raise exception 'Room number and name must be 1-100 characters'; end if;
 if v_type not in ('room','villa','chalet','cottage','suite','other') or v_type is null then raise exception 'Invalid accommodation type'; end if;
 insert into public.gs_motel_room_qr(room_label,room_name,accommodation_type) values(v_label,v_name,v_type)
 on conflict (room_label) do update set room_name=excluded.room_name,accommodation_type=excluded.accommodation_type;
 return query select t.room_label,t.room_name,t.accommodation_type from public.gs_motel_room_qr t where t.room_label=v_label;
end; $$;
revoke all on function public.gs_staff_save_motel_room(text,text,text) from public,anon;
grant execute on function public.gs_staff_save_motel_room(text,text,text) to authenticated;
create or replace function public.gs_staff_list_motel_rooms()
returns table(room_label text, room_name text, accommodation_type text, is_active boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_view') then raise exception 'Motel view permission denied'; end if;
 return query select t.room_label,t.room_name,t.accommodation_type,t.is_active from public.gs_motel_room_qr t order by t.room_label;
end; $$;
revoke all on function public.gs_staff_list_motel_rooms() from public,anon;
grant execute on function public.gs_staff_list_motel_rooms() to authenticated;
