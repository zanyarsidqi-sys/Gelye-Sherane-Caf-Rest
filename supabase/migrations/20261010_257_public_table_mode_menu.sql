-- Upgrade 257: QR-scoped, mode-aware customer menu (READ ONLY).
-- Do not confuse a publicly scannable table token with authorization to see
-- private bills, guest identities, or to create/modify paid orders.
-- Public deployment requires rate limits and abuse monitoring at the edge.
create or replace function public.gs_public_table_menu(p_token uuid)
returns table(table_number integer, product_id bigint, product_name text,
                  unit_price_iqd bigint, pricing_mode text)
language plpgsql stable security definer set search_path = '' as $$
declare v_table_id bigint; v_number integer; v_tourism boolean;
        v_discount public.gs_cafe_discount_modes%rowtype;
        v_mode text;
begin
  select t.id,t.table_number,t.tourism_mode
    into v_table_id,v_number,v_tourism
    from public.gs_table_qr_tokens q
    join public.gs_cafe_tables t on t.id=q.table_id
    where q.token=p_token and t.occupied=true;
  if v_table_id is null then raise exception 'Table session unavailable'; end if;
  if not exists(select 1 from public.cafe_website_settings s
                where s.id=1 and s.menu_enabled=true) then
    raise exception 'Customer menu unavailable';
  end if;
  select d.* into v_discount from public.gs_cafe_discount_modes d
    where d.scope='table' and d.scope_reference=v_number::text and d.is_active=true;
  v_mode := case when v_discount.id is not null then v_discount.base_mode
                 when v_tourism then 'tourism' else 'normal' end;
  -- Owner prices are not exposed until a dedicated, verified owner-price
  -- source is implemented. Fail closed rather than display incorrect prices.
  if v_mode='owner' then raise exception 'Owner pricing not configured for public menu'; end if;
  return query
  select v_number,p.id,p.name,
    (case when v_discount.id is null then
      case when v_mode='tourism' then p.tourism_price_iqd else p.normal_price_iqd end
     when v_discount.discount_type='percent' then
      greatest(0,round((case when v_mode='tourism' then p.tourism_price_iqd
                         else p.normal_price_iqd end)::numeric *
                    (1-v_discount.discount_value/100))::bigint)
     else greatest(0,(case when v_mode='tourism' then p.tourism_price_iqd
                            else p.normal_price_iqd end) - v_discount.discount_value::bigint)
     end)::bigint,
     (case when v_discount.id is not null then v_mode||'_discount'
           else v_mode end)::text
  from public.gs_menu_products p
  where p.is_active=true order by p.name limit 500;
end; $$;
revoke all on function public.gs_public_table_menu(uuid) from public;
grant execute on function public.gs_public_table_menu(uuid) to anon,authenticated;
-- Prices are DISPLAY QUOTES only: server must re-price and snapshot at
-- submission, and must reject stale/mismatched table visit/session tokens.
-- QR rotation and checkout should invalidate access; full visit-scoped
-- customer order authorization is a separate pending implementation.
