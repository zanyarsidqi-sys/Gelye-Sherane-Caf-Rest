-- Upgrade 1201: permission-scoped staff waste/correction history.
-- The original order item remains immutable; approved removals are reflected
-- in gs_correction_adjusted_order_bill / gs_corrected_invoice_quote.
create or replace function public.gs_staff_correction_waste_list(p_order_id bigint)
returns table(correction_id bigint,item_id bigint,reason text,details text,
 requested_quantity integer,decision text,requested_at timestamptz,
 replacement_product_id bigint,replacement_product_name text,replacement_item_id bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view')
 or public.gs_can_access('invoices_payments','can_view')) then
 raise exception 'Staff correction viewing permission required'; end if;
 return query select c.id,c.item_id,c.reason,c.details,c.requested_quantity,
 c.decision,c.requested_at,c.replacement_product_id,p.name,c.replacement_item_id
 from public.gs_order_item_corrections c
 left join public.gs_menu_products p on p.id=c.replacement_product_id
 where c.order_id=p_order_id order by c.requested_at desc,c.id desc;
end; $$;
revoke all on function public.gs_staff_correction_waste_list(bigint) from public,anon;
grant execute on function public.gs_staff_correction_waste_list(bigint) to authenticated;
