-- Public room QR resolves descriptive physical-room metadata only.
-- Do not expose occupancy, guest names, booking IDs, bills or order records.
create or replace function public.gs_public_motel_room_details(p_token text)
returns table(room_label text, room_name text, accommodation_type text)
language plpgsql security definer set search_path = '' as $$
declare v_token uuid;
begin
  begin v_token := p_token::uuid;
  exception when invalid_text_representation then return; end;
  return query
    select r.room_label, r.room_name, r.accommodation_type
    from public.gs_motel_room_qr r
    where r.public_token = v_token and r.is_active;
end; $$;
revoke all on function public.gs_public_motel_room_details(text) from public;
grant execute on function public.gs_public_motel_room_details(text) to anon, authenticated;
