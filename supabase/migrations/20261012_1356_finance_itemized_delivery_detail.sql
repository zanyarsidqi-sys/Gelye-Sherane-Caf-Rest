-- Upgrade: permission-scoped, read-only itemized finance detail.
-- Missing delivery/contact fields are explicitly null, never fabricated.
create or replace function public.gs_finance_itemized_order_detail(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_order record; v_items jsonb;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
  raise exception 'Payments view permission required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order id' using errcode='22023'; end if;
 select o.id,o.destination,o.is_motel,o.status,o.created_at into v_order
 from public.gs_orders o where o.id=p_order_id;
 if not found then raise exception 'Order not found' using errcode='P0002'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'item_id',i.id,'product_name',p.name,'quantity',i.quantity,
  'unit_price_iqd',i.unit_price_iqd,'line_total_iqd',i.line_total_iqd,
  'ordered_at',v_order.created_at,'individual_customer',null)
  order by i.id),'[]'::jsonb) into v_items
 from public.gs_order_items i join public.gs_menu_products p on p.id=i.product_id
 where i.order_id=p_order_id;
 return jsonb_build_object('order_id',v_order.id,'destination',v_order.destination,
 'is_motel',v_order.is_motel,'status',v_order.status,'created_at',v_order.created_at,
 'items',v_items,'delivery_address',null,'customer_phone',null,
 'requested_delivery_at',null,'room_number',null,
 'delivery_employee_id',null,'delivery_status',null,
 'settlement_verified',false);
end; $$;
revoke all on function public.gs_finance_itemized_order_detail(bigint) from public,anon;
grant execute on function public.gs_finance_itemized_order_detail(bigint) to authenticated;

create or replace function public.gs_finance_motel_request_detail(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_req record; v_items jsonb;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_view'),false) then
  raise exception 'Payments view permission required' using errcode='42501';
 end if;
 if p_request_id is null then raise exception 'Request ID required' using errcode='22023'; end if;
 select r.id,r.status,r.created_at,r.total_iqd,r.delivery_employee_id,
 r.delivery_assigned_at,r.delivered_at,room.room_label
 into v_req from public.gs_motel_guest_food_requests r
 join public.gs_motel_room_qr room on room.id=r.room_id
 where r.id=p_request_id;
 if not found then raise exception 'Motel request not found' using errcode='P0002'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('item_id',i.id,
 'product_name',i.product_name,'quantity',i.quantity,
 'unit_price_iqd',i.unit_price_iqd,'line_total_iqd',i.line_total_iqd,
 'ordered_at',v_req.created_at) order by i.product_name),'[]'::jsonb)
 into v_items from public.gs_motel_guest_food_request_items i where i.request_id=p_request_id;
 return jsonb_build_object('request_id',v_req.id,'room_number',v_req.room_label,
 'status',v_req.status,'delivery_status',v_req.status,
 'delivery_employee_id',v_req.delivery_employee_id,
 'delivery_assigned_at',v_req.delivery_assigned_at,'delivered_at',v_req.delivered_at,
 'requested_delivery_at',null,'created_at',v_req.created_at,
 'total_iqd',v_req.total_iqd,'items',v_items,'settlement_verified',false);
end; $$;
revoke all on function public.gs_finance_motel_request_detail(uuid) from public,anon;
grant execute on function public.gs_finance_motel_request_detail(uuid) to authenticated;
