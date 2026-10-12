-- Upgrade 527: require an employee-provided, auditable reason for each quantity correction.
-- The previous three-argument function is disabled before introducing the four-argument API.
revoke all on function public.gs_correct_unaccepted_table_item_quantity(bigint,integer,integer) from public,anon,authenticated;
-- Upgrade 524: server-side stored price guard for quantity corrections.
-- Upgrade 522: transactionally correct quantities only before acceptance.
-- No client price input; stored unit price remains the charged price.
-- Existing invoice snapshots, kitchen tickets and fulfilled items block edits.
create or replace function public.gs_correct_unaccepted_table_item_quantity(
 p_order_item_id bigint, p_expected_quantity integer, p_new_quantity integer, p_reason text)
returns bigint language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_old integer; v_price bigint; v_status text;
 v_visit_status text; v_fulfillment text; v_revision integer; v_event uuid;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 5 and 250 then
  raise exception 'A correction reason (5-250 characters) is required'; end if;
 if p_order_item_id is null or p_order_item_id<=0 or
    p_expected_quantity is null or p_expected_quantity not between 1 and 999 or
    p_new_quantity is null or p_new_quantity not between 1 and 999 then
  raise exception 'Invalid item or quantity'; end if;
 select i.order_id into v_order_id from public.gs_order_items i where i.id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 perform 1 from public.gs_orders where id=v_order_id for update;
 select o.status,v.status into v_status,v_visit_status
 from public.gs_orders o left join public.gs_table_visits v on v.id=o.table_visit_id
 where o.id=v_order_id and o.is_motel=false;
 if not found or v_status is distinct from 'new' or v_visit_status is distinct from 'open' then
  raise exception 'Order or visit is no longer editable'; end if;
 select i.quantity,i.unit_price_iqd into v_old,v_price from public.gs_order_items i
 where i.id=p_order_item_id and i.order_id=v_order_id for update;
 if not found or v_old<>p_expected_quantity then
  raise exception 'Quantity changed; refresh before editing'; end if;
 select coalesce(f.status,'not_accepted') into v_fulfillment
 from public.gs_order_items i left join public.gs_table_item_fulfillment f
 on f.order_item_id=i.id where i.id=p_order_item_id;
 if v_price is null or v_price < 0 or v_price > 1000000000 then
  raise exception 'Invalid stored unit price; correction blocked'; end if;
 if v_fulfillment<>'not_accepted' then
  raise exception 'Item already accepted; use supervised correction'; end if;
 if exists(select 1 from public.gs_cafe_order_station_ticket_items
           where order_item_id=p_order_item_id) then
  raise exception 'Preparation ticket already exists'; end if;
 if exists(select 1 from public.gs_admin_discount_invoice_snapshots
           where order_id=v_order_id) then
  raise exception 'Invoice already locked'; end if;
 if v_old=p_new_quantity then return v_old::bigint; end if;
 update public.gs_order_items set quantity=p_new_quantity where id=p_order_item_id;
 -- Serialize revision allocation per order via the existing parent row lock.
 select coalesce(max(revision_number),0)+1 into v_revision
 from public.gs_order_revision_events where order_id=v_order_id;
 insert into public.gs_order_revision_events
 (order_id,order_item_id,revision_number,change_type,before_snapshot,
 after_snapshot,changed_by,reason)
 values(v_order_id,p_order_item_id,v_revision,'quantity',
 jsonb_build_object('quantity',v_old,'unit_price_iqd',v_price,
                    'line_total_iqd',v_old::bigint*v_price),
 jsonb_build_object('quantity',p_new_quantity,'unit_price_iqd',v_price,
                    'line_total_iqd',p_new_quantity::bigint*v_price),
 auth.uid(),btrim(p_reason))
 returning id into v_event;
 insert into public.gs_order_revision_dispatch
 (revision_id,destination_type,destination_key)
 values(v_event,'employee_notification','table_orders'),
       (v_event,'customer_update','order:'||v_order_id::text)
 on conflict(revision_id,destination_type,destination_key) do nothing;
 return p_new_quantity::bigint;
end $$;
revoke all on function public.gs_correct_unaccepted_table_item_quantity(bigint,integer,integer,text)
 from public,anon;
grant execute on function public.gs_correct_unaccepted_table_item_quantity(bigint,integer,integer,text)
 to authenticated;
