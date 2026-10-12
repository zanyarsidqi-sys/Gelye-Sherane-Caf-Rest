-- Inventory history is read-only and scoped to authenticated employees with inventory view permission.
create or replace function public.gs_inventory_history(p_product_id bigint, p_limit integer default 50)
returns table(movement_id bigint, delta bigint, reason text, employee_id uuid, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('products_inventory','can_view') then
  raise exception 'Inventory history access denied';
 end if;
 if p_product_id is null or p_limit is null or p_limit < 1 or p_limit > 100 then
  raise exception 'Invalid history query';
 end if;
 return query select m.id, m.delta, m.reason, m.employee_id, m.created_at
 from public.gs_inventory_movements m where m.product_id = p_product_id
 order by m.created_at desc, m.id desc limit p_limit;
end; $$;
revoke all on function public.gs_inventory_history(bigint,integer) from public;
grant execute on function public.gs_inventory_history(bigint,integer) to authenticated;
