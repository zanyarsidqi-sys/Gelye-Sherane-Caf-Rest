-- Upgrade 535: transactional product replacement before kitchen acceptance/payment.
-- Client cannot set price. All checks and revision/outbox writes occur atomically.
create or replace function public.gs_replace_unaccepted_table_item(
 p_order_item_id bigint, p_expected_product_id bigint,
 p_expected_unit_price_iqd bigint, p_new_product_id bigint, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_old_product bigint; v_old_price bigint;
 v_quantity integer; v_new_price bigint; v_name text; v_mode boolean;
 v_status text; v_visit_status text; v_fulfillment text;
 v_revision integer; v_event uuid;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 5 and 250 then
  raise exception 'A replacement reason (5-250 characters) is required'; end if;
 if p_order_item_id is null or p_order_item_id <= 0 or
    p_expected_product_id is null or p_expected_product_id <= 0 or
    p_new_product_id is null or p_new_product_id <= 0 or
    p_expected_unit_price_iqd is null or p_expected_unit_price_iqd < 0 then
  raise exception 'Invalid replacement request'; end if;
 select order_id into v_order_id from public.gs_order_items where id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 perform 1 from public.gs_orders where id=v_order_id for update;
 select o.status,v.status,o.tourism_mode into v_status,v_visit_status,v_mode
 from public.gs_orders o left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=v_order_id and o.is_motel=false;
 if not found or v_status is distinct from 'new' or v_visit_status is distinct from 'open' then
  raise exception 'Order or visit is no longer editable'; end if;
 select product_id,unit_price_iqd,quantity into v_old_product,v_old_price,v_quantity
 from public.gs_order_items where id=p_order_item_id and order_id=v_order_id for update;
 if not found or v_old_product is distinct from p_expected_product_id or
    v_old_price is distinct from p_expected_unit_price_iqd then
  raise exception 'Item or price changed; refresh before replacing'; end if;
 if v_old_product=p_new_product_id then raise exception 'Choose a different product'; end if;
 select coalesce(f.status,'not_accepted') into v_fulfillment
 from public.gs_order_items i left join public.gs_table_item_fulfillment f
 on f.order_item_id=i.id where i.id=p_order_item_id;
 if v_fulfillment <> 'not_accepted' then raise exception 'Item already accepted'; end if;
 if exists(select 1 from public.gs_cafe_order_station_ticket_items where order_item_id=p_order_item_id)
 or exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=v_order_id)
 or exists(select 1 from public.gs_item_payment_allocations where order_id=v_order_id or order_item_id=p_order_item_id)
 or exists(select 1 from public.gs_cash_payments where order_id=v_order_id)
 or exists(select 1 from public.gs_unified_payment_ledger where order_id=v_order_id)
 or exists(select 1 from public.gs_external_payment_evidence where order_id=v_order_id)
 then raise exception 'Tickets, invoices or payment evidence exist; supervised reconciliation required'; end if;
 select case when v_mode then tourism_price_iqd else normal_price_iqd end,name
 into v_new_price,v_name from public.gs_menu_products
 where id=p_new_product_id and is_active=true for share;
 if not found or v_new_price is null or v_new_price < 0 or v_new_price > 1000000000 then
  raise exception 'Replacement product unavailable or invalid price'; end if;
 update public.gs_order_items set product_id=p_new_product_id,unit_price_iqd=v_new_price
 where id=p_order_item_id;
 select coalesce(max(revision_number),0)+1 into v_revision
 from public.gs_order_revision_events where order_id=v_order_id;
 -- Existing revision change_type constraint permits price_adjustment.
 insert into public.gs_order_revision_events
 (order_id,order_item_id,revision_number,change_type,before_snapshot,after_snapshot,changed_by,reason)
 values(v_order_id,p_order_item_id,v_revision,'price_adjustment',
 jsonb_build_object('product_id',v_old_product,'unit_price_iqd',v_old_price,
 'quantity',v_quantity,'line_total_iqd',v_quantity::bigint*v_old_price),
 jsonb_build_object('product_id',p_new_product_id,'product_name',v_name,
 'unit_price_iqd',v_new_price,'quantity',v_quantity,
 'line_total_iqd',v_quantity::bigint*v_new_price),auth.uid(),btrim(p_reason))
 returning id into v_event;
 insert into public.gs_order_revision_dispatch(revision_id,destination_type,destination_key)
 values(v_event,'employee_notification','table_orders'),
 (v_event,'customer_update','order:'||v_order_id::text)
 on conflict(revision_id,destination_type,destination_key) do nothing;
 return jsonb_build_object('order_item_id',p_order_item_id,'product_id',p_new_product_id,
 'product_name',v_name,'unit_price_iqd',v_new_price,'quantity',v_quantity,
 'old_line_total_iqd',v_quantity::bigint*v_old_price,
 'new_line_total_iqd',v_quantity::bigint*v_new_price,
 'difference_iqd',v_quantity::bigint*(v_new_price-v_old_price),
 'revision_id',v_event);
end $$;
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text)
 from public,anon;
grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text)
 to authenticated;
