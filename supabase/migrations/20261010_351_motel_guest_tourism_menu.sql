-- Upgrade 351: verified-stay motel menu quotes. Read-only, always Tourism pricing.
-- A QR alone does not authorize access. No price is accepted from the client for orders.
create or replace function public.gs_public_motel_guest_menu(p_room_token text,p_access_token text)
returns table(product_id bigint,product_name text,unit_price_iqd bigint,pricing_mode text)
language plpgsql stable security definer set search_path = '' as $$
declare v_session uuid;
begin
  begin
    select s.id into v_session from public.gs_motel_room_qr r
    join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
    where r.public_token=p_room_token::uuid and s.access_token=p_access_token::uuid
      and r.is_active and s.revoked_at is null and s.expires_at>now();
  exception when invalid_text_representation then
    raise exception 'Invalid guest access';
  end;
  if v_session is null then raise exception 'Invalid or expired guest access'; end if;
  if not exists(select 1 from public.cafe_website_settings w where w.id=1 and w.menu_enabled=true) then
    raise exception 'Guest menu unavailable';
  end if;
  return query select p.id,p.name,p.tourism_price_iqd,'tourism'::text
    from public.gs_menu_products p where p.is_active=true
    order by p.name limit 500;
end; $$;
revoke all on function public.gs_public_motel_guest_menu(text,text) from public;
grant execute on function public.gs_public_motel_guest_menu(text,text) to anon,authenticated;
