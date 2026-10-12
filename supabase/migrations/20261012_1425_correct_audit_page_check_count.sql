-- Correct the original page contract: per-order audit has exactly 12 checks.
-- Read-only, bounded, permission-gated order audit page. No payment posting or total certification.
-- A stable keyset page avoids OFFSET drift and does not claim global source completeness.
create or replace function public.gs_financial_order_integrity_page(
 p_after_order_id bigint default 0, p_page_size integer default 25,
 p_source text default 'all')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
 v_ids bigint[];
 v_id bigint;
 v_rows jsonb := '[]'::jsonb;
 v_next bigint := null;
 v_more boolean := false;
 v_count integer := 0;
 v_failed integer := 0;
 v_unverified integer := 0;
 v_result jsonb;
 v_checks jsonb;
begin
 -- The per-order audit also rechecks authorization for each order.
 if (select auth.uid()) is null or
    not coalesce(public.gs_can_access('payments_management','can_view'),false) then
   raise exception 'Payments Management viewing permission required' using errcode='42501';
 end if;
 if p_after_order_id is null or p_after_order_id < 0 then
   raise exception 'Invalid cursor' using errcode='22023';
 end if;
 if p_page_size is null or p_page_size < 1 or p_page_size > 50 then
   raise exception 'Page size must be between 1 and 50' using errcode='22023';
 end if;
 if p_source is null or p_source not in ('all','table','motel') then
   raise exception 'Invalid source' using errcode='22023';
 end if;
 -- Fetch one extra ID to prove whether another page exists.
 select coalesce(array_agg(id order by id),'{}'::bigint[]) into v_ids from (
   select o.id from public.gs_orders o
   where o.id > p_after_order_id
     and (p_source='all' or (p_source='motel' and o.is_motel is true)
          or (p_source='table' and o.is_motel is false and o.table_visit_id is not null))
   order by o.id limit p_page_size + 1
 ) page;
 v_more := coalesce(array_length(v_ids,1),0)>p_page_size;
 foreach v_id in array v_ids loop
   exit when v_count >= p_page_size;
   v_result := public.gs_financial_order_integrity_audit(v_id);
   if jsonb_typeof(v_result) <> 'object' or v_result->>'order_id' <> v_id::text
      or v_result->>'verified_complete' <> 'false' then
      raise exception 'Unexpected audit response' using errcode='22023';
   end if;
   v_checks := v_result->'checks';
   if jsonb_typeof(v_checks) <> 'object' or (select count(*) from jsonb_object_keys(v_checks)) <> 12 then
      raise exception 'Incomplete audit checks' using errcode='22023';
   end if;
   if exists(select 1 from jsonb_each(v_checks) x where x.value <> 'true'::jsonb) then
      v_failed := v_failed + 1;
   end if;
   v_unverified := v_unverified + 1;
   v_rows := v_rows || jsonb_build_array(v_result);
   v_next := v_id;
   v_count := v_count + 1;
 end loop;
 return jsonb_build_object(
   'source',p_source,'after_order_id',p_after_order_id,'page_size',p_page_size,
   'returned_count',v_count,'has_more',v_more,'next_after_order_id',v_next,
   'orders_with_failed_checks',v_failed,'uncertified_orders',v_unverified,
   'audits',v_rows,'verified_complete',false,'settlement_confirmed',false,
   'totals_available',false,'generated_at',now(),
   'warning','Keyset-paginated diagnostic page only. Does not establish complete settlement coverage or certified outstanding totals.');
end; $$;
revoke all on function public.gs_financial_order_integrity_page(bigint,integer,text) from public,anon;
grant execute on function public.gs_financial_order_integrity_page(bigint,integer,text) to authenticated;
