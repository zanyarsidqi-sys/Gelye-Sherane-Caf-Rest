-- Upgrade 207: conservative customer spend from attested CASH-ONLY orders.
-- Mixed/card/credit payments and unattested cash are deliberately excluded.
-- A customer is attributed only when exactly one profile is linked to the visit.
create or replace function public.gs_cafe_customer_verified_cash_spend()
returns table(customer_id bigint, customer_name text, visit_count bigint,
 cash_spent_iqd bigint, settled_orders bigint, last_settlement timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('customers','can_view') then
  raise exception 'Customer view permission required'; end if;
 return query
 with customer_visits as (
  select v.table_visit_id, min(v.customer_id) as customer_id
  from public.gs_cafe_customer_visits v
  where v.table_visit_id is not null
  group by v.table_visit_id having count(distinct v.customer_id)=1
 ), settled as (
  select cv.customer_id,a.order_id,a.collected_cash_iqd,a.attested_at
  from public.gs_cash_only_settlement_attestations a
  join public.gs_orders o on o.id=a.order_id and o.table_visit_id=a.table_visit_id
  join customer_visits cv on cv.table_visit_id=a.table_visit_id
  where o.status <> 'cancelled'
 ), totals as (
  select s.customer_id,coalesce(sum(s.collected_cash_iqd),0)::bigint as cash_spent,
   count(*)::bigint as orders,max(s.attested_at) as last_at
  from settled s group by s.customer_id
 ), visits as (
  select v.customer_id,count(*)::bigint as n
  from public.gs_cafe_customer_visits v group by v.customer_id
 )
 select c.id,c.full_name,coalesce(v.n,0)::bigint,
  coalesce(t.cash_spent,0)::bigint,coalesce(t.orders,0)::bigint,t.last_at
 from public.gs_cafe_customer_profiles c
 left join totals t on t.customer_id=c.id
 left join visits v on v.customer_id=c.id
 order by coalesce(t.cash_spent,0) desc,coalesce(v.n,0) desc,c.full_name
 limit 2000;
end $$;

create or replace function public.gs_cafe_customer_cash_spend_history(p_customer_id bigint)
returns table(order_id bigint,table_number integer,amount_iqd bigint,settled_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('customers','can_view') then
  raise exception 'Customer view permission required'; end if;
 return query
 select a.order_id,v.table_number,a.collected_cash_iqd,a.attested_at
 from public.gs_cash_only_settlement_attestations a
 join public.gs_orders o on o.id=a.order_id and o.table_visit_id=a.table_visit_id
 join public.gs_cafe_customer_visits cv on cv.table_visit_id=a.table_visit_id
 join public.gs_table_visits v on v.id=a.table_visit_id
 where cv.customer_id=p_customer_id and o.status <> 'cancelled'
 and (select count(distinct cv2.customer_id) from public.gs_cafe_customer_visits cv2
      where cv2.table_visit_id=a.table_visit_id)=1
 order by a.attested_at desc,a.order_id desc limit 500;
end $$;
revoke all on function public.gs_cafe_customer_verified_cash_spend(),
 public.gs_cafe_customer_cash_spend_history(bigint) from public,anon;
grant execute on function public.gs_cafe_customer_verified_cash_spend(),
 public.gs_cafe_customer_cash_spend_history(bigint) to authenticated;
