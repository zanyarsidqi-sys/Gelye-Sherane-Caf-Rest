-- Read-only cash reconciliation. Apply after migration 021.
create or replace function public.gs_cash_reconciliation(p_limit integer default 100)
returns table(order_id bigint, order_status text, order_total_iqd bigint, cash_paid_iqd bigint, balance_iqd bigint, cash_payment_count bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('payments_management') or public.gs_can_access('invoices_payments')) then
  raise exception 'Not authorized to review payments';
 end if;
 return query
 select o.id, o.status::text,
   coalesce((select sum(i.line_total_iqd) from public.gs_order_items i where i.order_id=o.id),0)::bigint,
   coalesce((select sum(p.amount_iqd) from public.gs_cash_payments p where p.order_id=o.id),0)::bigint,
   (coalesce((select sum(i.line_total_iqd) from public.gs_order_items i where i.order_id=o.id),0) -
    coalesce((select sum(p.amount_iqd) from public.gs_cash_payments p where p.order_id=o.id),0))::bigint,
   (select count(*) from public.gs_cash_payments p where p.order_id=o.id)::bigint
 from public.gs_orders o order by o.id desc limit least(greatest(coalesce(p_limit,100),1),500);
end; $$;
revoke all on function public.gs_cash_reconciliation(integer) from public, anon;
grant execute on function public.gs_cash_reconciliation(integer) to authenticated;
