-- Phase 3 / Step 2: server-computed per-order cash payment summary.
-- Apply after migrations 021 and 022. This does NOT represent card/credit settlement.
create or replace function public.gs_order_cash_payment_summary(p_order_id bigint)
returns table(order_id bigint, order_total_iqd bigint, cash_paid_iqd bigint,
              cash_balance_iqd bigint, cash_status text, cash_payment_count bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (
    public.gs_can_access('invoices_payments') or
    public.gs_can_access('payments_management') or
    public.gs_can_access('table_orders') or
    public.gs_can_access('motel_orders')
  ) then
    raise exception 'Not authorized to review order payment status';
  end if;
  if p_order_id is null then raise exception 'Order ID required'; end if;
  if not exists(select 1 from public.gs_orders where id=p_order_id) then
    raise exception 'Order not found';
  end if;
  return query
  with totals as (
    select coalesce(sum(i.line_total_iqd),0)::bigint as total
    from public.gs_order_items i where i.order_id=p_order_id
  ), payments as (
    select coalesce(sum(p.amount_iqd),0)::bigint as paid,
           count(*)::bigint as payment_count
    from public.gs_cash_payments p where p.order_id=p_order_id
  )
  select p_order_id, t.total, p.paid, greatest(t.total-p.paid,0)::bigint,
    case when t.total<=0 then 'unknown'
         when p.paid=0 then 'unpaid'
         when p.paid<t.total then 'partially_paid'
         else 'paid_in_cash' end::text,
    p.payment_count
  from totals t cross join payments p;
end; $$;
revoke all on function public.gs_order_cash_payment_summary(bigint) from public, anon;
grant execute on function public.gs_order_cash_payment_summary(bigint) to authenticated;
