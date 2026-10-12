-- Upgrade 529: permission-scoped, read-only financial preview for quantity corrections.
-- Preview is informational; the mutation RPC from Upgrade 528 must independently
-- repeat all authorization, payment, invoice and kitchen checks under locks.
create or replace function public.gs_preview_unaccepted_table_item_quantity(
 p_order_item_id bigint, p_expected_quantity integer, p_new_quantity integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_order_id bigint; v_old integer; v_price bigint;
 v_order_status text; v_visit_status text; v_fulfillment text;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required'; end if;
 if p_order_item_id is null or p_order_item_id <= 0 or
    p_expected_quantity is null or p_expected_quantity not between 1 and 999 or
    p_new_quantity is null or p_new_quantity not between 1 and 999 then
  raise exception 'Invalid item or quantity'; end if;
 select i.order_id,i.quantity,i.unit_price_iqd
 into v_order_id,v_old,v_price from public.gs_order_items i
 where i.id=p_order_item_id;
 if not found or v_old is distinct from p_expected_quantity then
  raise exception 'Quantity changed; refresh before editing'; end if;
 select o.status,v.status into v_order_status,v_visit_status
 from public.gs_orders o left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=v_order_id and o.is_motel=false;
 if not found or v_order_status is distinct from 'new' or
    v_visit_status is distinct from 'open' then
  raise exception 'Order or visit is no longer editable'; end if;
 select coalesce(f.status,'not_accepted') into v_fulfillment
 from public.gs_order_items i left join public.gs_table_item_fulfillment f
 on f.order_item_id=i.id where i.id=p_order_item_id;
 if v_fulfillment <> 'not_accepted' then
  raise exception 'Item already accepted'; end if;
 if v_price is null or v_price < 0 or v_price > 1000000000 then
  raise exception 'Invalid stored unit price'; end if;
 if exists(select 1 from public.gs_cafe_order_station_ticket_items
           where order_item_id=p_order_item_id) or
    exists(select 1 from public.gs_admin_discount_invoice_snapshots
           where order_id=v_order_id) or
    exists(select 1 from public.gs_item_payment_allocations
           where order_item_id=p_order_item_id or order_id=v_order_id) or
    exists(select 1 from public.gs_cash_payments where order_id=v_order_id) or
    exists(select 1 from public.gs_unified_payment_ledger where order_id=v_order_id) or
    exists(select 1 from public.gs_external_payment_evidence where order_id=v_order_id)
 then raise exception 'Order has tickets, invoices or payment records; correction blocked'; end if;
 return jsonb_build_object(
  'previous_line_total_iqd',v_old::bigint*v_price,
  'new_line_total_iqd',p_new_quantity::bigint*v_price,
  'difference_iqd',(p_new_quantity::bigint-v_old::bigint)*v_price);
end $$;
revoke all on function public.gs_preview_unaccepted_table_item_quantity(bigint,integer,integer)
 from public,anon;
grant execute on function public.gs_preview_unaccepted_table_item_quantity(bigint,integer,integer)
 to authenticated;
