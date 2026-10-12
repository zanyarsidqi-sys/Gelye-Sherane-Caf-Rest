-- Upgrade 182: permission checked search by name or barcode; no direct table reads.
create or replace function public.gs_search_counter_menu_products(p_query text)
returns table(product_id bigint,name text,barcode text,
 normal_price_iqd bigint,tourism_price_iqd bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_q text;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Not authorized to search menu for counter orders';
 end if;
 v_q := trim(coalesce(p_query,''));
 if length(v_q) < 1 or length(v_q) > 80 then
  raise exception 'Search must be between 1 and 80 characters';
 end if;
 return query select p.id,p.name,p.barcode,p.normal_price_iqd,p.tourism_price_iqd
 from public.gs_menu_products p
 where p.is_active is true
   and (lower(p.name) like '%' || lower(replace(replace(v_q,'%', '\%'),'_', '\_')) || '%' escape '\'
     or p.barcode = v_q)
 order by case when p.barcode=v_q then 0 else 1 end,p.name,p.id
 limit 30;
end; $$;
revoke all on function public.gs_search_counter_menu_products(text) from public,anon;
grant execute on function public.gs_search_counter_menu_products(text) to authenticated;
