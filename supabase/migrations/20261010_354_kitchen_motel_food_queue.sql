-- Upgrade 354: accepted guest food requests become visible to kitchen staff.
-- Read-only preparation queue; no kitchen ticket, charge, inventory mutation, or dispatch.
create or replace function public.gs_kitchen_list_accepted_motel_food()
returns table(id uuid, room_label text, room_name text, status text, total_iqd bigint, created_at timestamptz, items jsonb)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('kitchen','can_view'),false) then
  raise exception 'Not authorized';
 end if;
 return query
 select o.id,r.room_label,r.room_name,o.status,o.total_iqd,o.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,'price_iqd',i.unit_price_iqd)
 order by i.product_name) from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb)
 from public.gs_motel_guest_food_requests o
 join public.gs_motel_room_qr r on r.id=o.room_id
 where o.status='accepted'
 order by o.created_at asc limit 200;
end; $$;
revoke all on function public.gs_kitchen_list_accepted_motel_food() from public;
grant execute on function public.gs_kitchen_list_accepted_motel_food() to authenticated;
