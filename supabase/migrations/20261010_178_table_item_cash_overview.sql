-- Upgrade 178: read-only per-table item lifecycle and cash-only outstanding.
-- Requires table_visit_id (migration 051), gs_cash_payments (021).
create table if not exists public.gs_table_item_fulfillment (
 order_item_id bigint primary key references public.gs_order_items(id) on delete restrict,
 status text not null default 'not_accepted' check(status in
  ('not_accepted','accepted','preparing','prepared','picked_up','delivered')),
 accepted_by uuid references auth.users(id),
 prepared_by uuid references auth.users(id),
 picked_by uuid references auth.users(id),
 delivered_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
alter table public.gs_table_item_fulfillment enable row level security;
revoke all on public.gs_table_item_fulfillment from public,anon,authenticated;
-- Fulfillment transitions intentionally not enabled until order/Kitchen roles and
-- partial quantity delivery are designed. Absence of row means not_accepted.

create or replace function public.gs_table_item_money_overview(p_table_number integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if auth.uid() is null or not (
   public.gs_can_access('tables','can_view') or
   public.gs_can_access('table_orders','can_view') or
   public.gs_can_access('invoices_payments','can_view')
 ) then raise exception 'Not authorized to view table item summary'; end if;
 if not exists(select 1 from public.gs_cafe_tables t
    where t.table_number=p_table_number) then raise exception 'Table not found'; end if;
 with active_visit as (
   select v.id from public.gs_table_visits v
   join public.gs_cafe_tables t on t.id=v.table_id
   where t.table_number=p_table_number and v.status='open'
   order by v.opened_at desc limit 1
 ), orders as (
   select o.id,o.status from public.gs_orders o
   join active_visit v on v.id=o.table_visit_id
   where o.status <> 'cancelled'
 ), items as (
   select i.id,i.order_id,i.quantity,i.unit_price_iqd,i.line_total_iqd,
     p.name,coalesce(f.status,'not_accepted') as fulfillment_status,
     f.accepted_by,f.prepared_by,f.picked_by,f.delivered_by
   from public.gs_order_items i join orders o on o.id=i.order_id
   join public.gs_menu_products p on p.id=i.product_id
   left join public.gs_table_item_fulfillment f on f.order_item_id=i.id
 ), totals as (
   select coalesce(sum(line_total_iqd),0)::bigint as billed from items
 ), paid as (
   select coalesce(sum(cp.amount_iqd),0)::bigint as cash_paid
   from public.gs_cash_payments cp join orders o on o.id=cp.order_id
 )
 select jsonb_build_object(
  'table_number',p_table_number,
  'items',coalesce((select jsonb_agg(jsonb_build_object(
    'order_item_id',i.id,'order_id',i.order_id,'product',i.name,
    'quantity',i.quantity,'unit_price_iqd',i.unit_price_iqd,
    'amount_iqd',i.line_total_iqd,'status',i.fulfillment_status,
    'accepted_by',i.accepted_by,'prepared_by',i.prepared_by,
    'picked_by',i.picked_by,'delivered_by',i.delivered_by)
    order by i.order_id,i.id) from items i),'[]'::jsonb),
  'billed_iqd',(select billed from totals),
  'verified_cash_paid_iqd',(select cash_paid from paid),
  'cash_only_outstanding_iqd',greatest(
    (select billed from totals)-(select cash_paid from paid),0),
  'payment_scope','cash_only_unreconciled',
  'warning','Credit, mixed and unified ledger payments are not reconciled here; do not use as final settlement balance.'
 ) into v_result;
 return v_result;
end; $$;
revoke all on function public.gs_table_item_money_overview(integer) from public,anon;
grant execute on function public.gs_table_item_money_overview(integer) to authenticated;
