-- Upgrade 537: bounded, server-side catalog search for authorized staff.
-- Only catalog fields needed for a replacement are exposed.
create or replace function public.gs_search_table_replacement_products(
 p_query text default '', p_limit integer default 40, p_offset integer default 0)
returns table(id bigint,name text,barcode text,normal_price_iqd bigint,tourism_price_iqd bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Table order editing permission required';
 end if;
 if p_limit is null or p_limit not between 1 and 60 or
    p_offset is null or p_offset not between 0 and 10000 or
    length(coalesce(p_query,'')) > 100 then
  raise exception 'Invalid catalog search parameters';
 end if;
 return query
 select p.id,p.name::text,p.barcode::text,p.normal_price_iqd::bigint,
        p.tourism_price_iqd::bigint
 from public.gs_menu_products p
 where p.is_active=true and
   (btrim(coalesce(p_query,''))='' or
    p.name ilike '%'||replace(replace(replace(btrim(p_query),'\\','\\\\'),'%','\\%'),'_','\\_')||'%' escape '\' or
    p.barcode ilike '%'||replace(replace(replace(btrim(p_query),'\\','\\\\'),'%','\\%'),'_','\\_')||'%' escape '\')
 order by p.name,p.id limit p_limit offset p_offset;
end $$;
revoke all on function public.gs_search_table_replacement_products(text,integer,integer) from public,anon;
grant execute on function public.gs_search_table_replacement_products(text,integer,integer) to authenticated;
