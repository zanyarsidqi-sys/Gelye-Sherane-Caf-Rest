-- Upgrade 356: guest-session-scoped read-only food order tracking.
-- Does not reveal other stays, charge rooms, or dispatch kitchen tickets.
create or replace function public.gs_public_motel_food_order_status(
 p_room_token text,p_access_token text)
returns table(order_id uuid,status text,total_iqd bigint,created_at timestamptz,items jsonb)
language plpgsql security definer set search_path = '' as $$
declare v_session uuid;
begin
 begin
  select s.id into v_session from public.gs_motel_room_qr r
  join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
  where r.public_token=p_room_token::uuid and s.access_token=p_access_token::uuid
   and r.is_active and s.revoked_at is null and s.expires_at>now();
 exception when invalid_text_representation then raise exception 'Invalid guest access'; end;
 if v_session is null then raise exception 'Invalid or expired guest access'; end if;
 return query
 select o.id,o.status,o.total_iqd,o.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,
 'unit_price_iqd',i.unit_price_iqd,'line_total_iqd',i.line_total_iqd) order by i.product_name)
 from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb)
 from public.gs_motel_guest_food_requests o
 where o.guest_session_id=v_session order by o.created_at desc limit 50;
end; $$;
revoke all on function public.gs_public_motel_food_order_status(text,text) from public;
grant execute on function public.gs_public_motel_food_order_status(text,text) to anon,authenticated;
