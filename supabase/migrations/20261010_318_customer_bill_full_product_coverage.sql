-- Upgrade 318: remove the 200-product cap that could understate gross totals.
-- Visit-scoped gross order preview only; NOT a payment balance.
-- This is NOT a payable balance: discounts, transfers, refunds, and payments
-- must be reconciled by a separate financial ledger function.
create or replace function public.gs_customer_visit_bill_preview(p_session_token uuid)
returns table(product_name text, quantity bigint, amount_iqd bigint)
language sql stable security definer set search_path='' as $$
 select p.name::text, sum(i.quantity)::bigint, sum(i.line_total_iqd)::bigint
 from public.gs_customer_visit_sessions s
 join public.gs_cafe_tables t on t.id=s.table_id and t.occupied=true
 join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id and v.status='open'
 join public.gs_orders o on o.table_visit_id=v.id and o.status<>'cancelled'
 join public.gs_order_items i on i.order_id=o.id
 join public.gs_menu_products p on p.id=i.product_id
 where s.session_token=p_session_token and s.revoked_at is null and s.expires_at>now()
 group by p.id,p.name order by p.name;
$$;
revoke all on function public.gs_customer_visit_bill_preview(uuid) from public;
grant execute on function public.gs_customer_visit_bill_preview(uuid) to anon,authenticated;
