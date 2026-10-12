-- Upgrade 565: transactionally record completed replacement requests.
create table if not exists public.gs_table_replacement_requests (
 request_id uuid primary key,
 actor_id uuid not null,
 arguments jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now()
);
revoke all on public.gs_table_replacement_requests from public, anon, authenticated;

create or replace function public.gs_replace_unaccepted_table_item(
 p_order_item_id bigint, p_expected_product_id bigint,
 p_expected_unit_price_iqd bigint, p_new_product_id bigint,
 p_reason text, p_confirmed_new_unit_price_iqd bigint,
 p_expected_quantity integer, p_expected_tourism_mode boolean,
 p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid := auth.uid(); v_args jsonb; v_previous record; v_result jsonb;
begin
 if v_actor is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_request_id is null then raise exception 'Request identity required'; end if;
 v_args := jsonb_build_object('order_item_id',p_order_item_id,
  'old_product_id',p_expected_product_id,'old_price',p_expected_unit_price_iqd,
  'new_product_id',p_new_product_id,'reason',p_reason,
  'new_price',p_confirmed_new_unit_price_iqd,'quantity',p_expected_quantity,
  'tourism_mode',p_expected_tourism_mode);
 -- Serializes same-key requests, including simultaneous requests on separate connections.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text,0));
 select * into v_previous from public.gs_table_replacement_requests where request_id=p_request_id;
 if found then
  if v_previous.actor_id <> v_actor or v_previous.arguments <> v_args then
   raise exception 'Request identity already used with different arguments';
  end if;
  return v_previous.result;
 end if;
 v_result := public.gs_replace_unaccepted_table_item(
  p_order_item_id,p_expected_product_id,p_expected_unit_price_iqd,
  p_new_product_id,p_reason,p_confirmed_new_unit_price_iqd,
  p_expected_quantity,p_expected_tourism_mode);
 insert into public.gs_table_replacement_requests(request_id,actor_id,arguments,result)
 values (p_request_id,v_actor,v_args,v_result);
 return v_result;
end $$;

create or replace function public.gs_table_replacement_request_result(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order viewing permission required';
 end if;
 select result into v_result from public.gs_table_replacement_requests
 where request_id=p_request_id and actor_id=auth.uid();
 return jsonb_build_object('completed',found,'result',v_result);
end $$;
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer,boolean) from public,anon,authenticated;
revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer,boolean,uuid) from public,anon,authenticated;
grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint,integer,boolean,uuid) to authenticated;
revoke all on function public.gs_table_replacement_request_result(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_request_result(uuid) to authenticated;
