-- Upgrade 358: guest-visible delivered-food bill preview, NOT a posted invoice or payment ledger.
-- Reuse the existing guest session authorization and server-stored tourism price snapshots.
create or replace function public.gs_public_motel_food_bill_preview(p_room_token text,p_access_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_session uuid; v_total bigint; v_orders jsonb;
begin
 begin
  select s.id into v_session from public.gs_motel_room_qr r
  join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
  where r.public_token=p_room_token::uuid and s.access_token=p_access_token::uuid
    and r.is_active and s.revoked_at is null and s.expires_at>now();
 exception when invalid_text_representation then raise exception 'Invalid guest access'; end;
 if v_session is null then raise exception 'Invalid or expired guest access'; end if;
 select coalesce(sum(o.total_iqd),0) into v_total
 from public.gs_motel_guest_food_requests o
 where o.guest_session_id=v_session and o.status='delivered';
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'delivered_at',x.delivered_at,
  'total_iqd',x.total_iqd,'items',x.items) order by x.delivered_at desc),'[]'::jsonb)
 into v_orders from (
  select o.id,o.delivered_at,o.total_iqd,
   coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,
    'unit_price_iqd',i.unit_price_iqd,'line_total_iqd',i.line_total_iqd) order by i.product_name)
    from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb) as items
  from public.gs_motel_guest_food_requests o
  where o.guest_session_id=v_session and o.status='delivered'
 ) x;
 return jsonb_build_object('delivered_food_total_iqd',v_total,'orders',v_orders,
  'is_official_invoice',false,'payment_status','not_available');
end; $$;
revoke all on function public.gs_public_motel_food_bill_preview(text,text) from public;
grant execute on function public.gs_public_motel_food_bill_preview(text,text) to anon,authenticated;
