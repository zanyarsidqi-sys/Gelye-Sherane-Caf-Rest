-- Upgrade 183: atomic removal of unsubmitted counter-request draft items.
create or replace function public.gs_remove_counter_request_menu_item(
 p_request_id bigint,p_item_id bigint)
returns void language plpgsql volatile security definer set search_path='' as $$
declare v_request public.gs_counter_order_requests%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Not authorized to edit counter requests'; end if;
 select * into v_request from public.gs_counter_order_requests
 where id=p_request_id for update;
 if not found then raise exception 'Request not found'; end if;
 if v_request.status <> 'pending' then
  raise exception 'Only pending requests can be edited'; end if;
 delete from public.gs_counter_order_request_items
 where id=p_item_id and request_id=p_request_id;
 if not found then raise exception 'Draft item not found'; end if;
end; $$;
revoke all on function public.gs_remove_counter_request_menu_item(bigint,bigint)
 from public,anon;
grant execute on function public.gs_remove_counter_request_menu_item(bigint,bigint)
 to authenticated;
