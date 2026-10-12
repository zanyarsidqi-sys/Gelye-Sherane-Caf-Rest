-- Upgrade 266: transactionally record and queue approved pre-acceptance instruction changes.
-- This is a narrow, safe integration: no post-dispatch edits or physical printing.
-- Run AFTER migrations 261 and 265.
create or replace function public.gs_edit_unaccepted_item_with_revision(
 p_order_item_id bigint, p_expected_instructions text, p_new_instructions text)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_order_id bigint; v_before text; v_after text; v_revision integer;
 v_event uuid; v_station text; v_expected text; v_requested text;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 -- Lock order first to serialize revisions and editing, as required by prior RPC.
 select i.order_id into v_order_id from public.gs_order_items i where i.id=p_order_item_id;
 if not found then raise exception 'Order item not found'; end if;
 perform 1 from public.gs_orders where id=v_order_id for update;
 select i.preparation_instructions into v_before from public.gs_order_items i
 where i.id=p_order_item_id for update;
 if not found then raise exception 'Order item not found'; end if;
 v_expected:=nullif(btrim(p_expected_instructions),'');
 v_requested:=nullif(btrim(p_new_instructions),'');
 -- Delegate all status, invoice, ticket, concurrency, and permission checks.
 v_after:=public.gs_edit_unaccepted_order_item_instructions(
   p_order_item_id,p_expected_instructions,p_new_instructions);
 v_after:=nullif(v_after,'');
 if v_before is not distinct from v_after then return null; end if;
 select coalesce(max(revision_number),0)+1 into v_revision
 from public.gs_order_revision_events where order_id=v_order_id;
 insert into public.gs_order_revision_events
  (order_id,order_item_id,revision_number,change_type,before_snapshot,
   after_snapshot,changed_by,reason)
 values (v_order_id,p_order_item_id,v_revision,'instructions',
   jsonb_build_object('preparation_instructions',v_before),
   jsonb_build_object('preparation_instructions',v_after),auth.uid(),
   'Authorized pre-acceptance preparation instruction correction')
 returning id into v_event;
 select pp.station_key into v_station
 from public.gs_order_items i
 join public.gs_cafe_product_preparation pp on pp.product_id=i.product_id
 where i.id=p_order_item_id;
 -- Queue staff alert and customer refresh. Do not queue a duplicate station
 -- print for an item not yet accepted/printed; original station ticket remains authoritative.
 insert into public.gs_order_revision_dispatch
  (revision_id,destination_type,destination_key)
 values (v_event,'employee_notification',coalesce(v_station,'table_orders')),
        (v_event,'customer_update','order:'||v_order_id::text)
 on conflict (revision_id,destination_type,destination_key) do nothing;
 return v_event;
end $$;
revoke all on function public.gs_edit_unaccepted_item_with_revision(bigint,text,text)
 from public,anon;
grant execute on function public.gs_edit_unaccepted_item_with_revision(bigint,text,text)
 to authenticated;
-- Prevent direct calls to the legacy edit RPC from bypassing revision dispatch.
revoke execute on function public.gs_edit_unaccepted_order_item_instructions(bigint,text,text)
 from authenticated;
-- The wrapper is SECURITY DEFINER and retains authority to call the older RPC.
