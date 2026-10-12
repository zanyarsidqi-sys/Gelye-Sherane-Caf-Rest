-- Upgrade 210: customer activity and attested cash analytics (Asia/Baghdad month buckets).
-- Financial amounts are cash-only, verified attestations, not all-method spend.
-- The customer/visit linkage must be unambiguous; no 500-row history truncation.
create or replace function public.gs_cafe_customer_performance(p_customer_id bigint)
returns table(first_visit timestamptz,last_visit timestamptz,total_visits bigint,
 attested_cash_iqd bigint,attested_cash_orders bigint,average_cash_order_iqd numeric)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('customers','can_view') then
  raise exception 'Customer view permission required'; end if;
 if not exists(select 1 from public.gs_cafe_customer_profiles where id=p_customer_id) then
  raise exception 'Customer not found'; end if;
 return query
 with visit_summary as (
  select min(v.visited_at) first_at,max(v.visited_at) last_at,count(*)::bigint n
  from public.gs_cafe_customer_visits v where v.customer_id=p_customer_id
 ), unique_visits as (
  select v.table_visit_id,min(v.customer_id) customer_id
  from public.gs_cafe_customer_visits v where v.table_visit_id is not null
  group by v.table_visit_id having count(distinct v.customer_id)=1
 ), cash_summary as (
  select coalesce(sum(a.collected_cash_iqd),0)::bigint amount,count(*)::bigint n
  from public.gs_cash_only_settlement_attestations a
  join public.gs_orders o on o.id=a.order_id and o.table_visit_id=a.table_visit_id
  join unique_visits u on u.table_visit_id=a.table_visit_id
  where u.customer_id=p_customer_id and o.status <> 'cancelled'
 )
 select v.first_at,v.last_at,v.n,c.amount,c.n,
  case when c.n>0 then round(c.amount::numeric/c.n,0) else 0::numeric end
 from visit_summary v cross join cash_summary c;
end $$;

create or replace function public.gs_cafe_customer_monthly_trend(p_customer_id bigint,p_months integer default 6)
returns table(month_start date,visit_count bigint,attested_cash_iqd bigint,attested_cash_orders bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('customers','can_view') then
  raise exception 'Customer view permission required'; end if;
 if p_months is null or p_months not between 1 and 24 then raise exception 'Invalid month count'; end if;
 if not exists(select 1 from public.gs_cafe_customer_profiles where id=p_customer_id) then
  raise exception 'Customer not found'; end if;
 return query
 with months as (
  select (date_trunc('month',now() at time zone 'Asia/Baghdad')::date - (g.i * interval '1 month'))::date m
  from generate_series(0,p_months-1) g(i)
 ), visits as (
  select date_trunc('month',v.visited_at at time zone 'Asia/Baghdad')::date m,count(*)::bigint n
  from public.gs_cafe_customer_visits v where v.customer_id=p_customer_id
  group by 1
 ), unique_visits as (
  select v.table_visit_id,min(v.customer_id) customer_id
  from public.gs_cafe_customer_visits v where v.table_visit_id is not null
  group by v.table_visit_id having count(distinct v.customer_id)=1
 ), cash as (
  select date_trunc('month',a.attested_at at time zone 'Asia/Baghdad')::date m,
   sum(a.collected_cash_iqd)::bigint amount,count(*)::bigint n
  from public.gs_cash_only_settlement_attestations a
  join public.gs_orders o on o.id=a.order_id and o.table_visit_id=a.table_visit_id
  join unique_visits u on u.table_visit_id=a.table_visit_id
  where u.customer_id=p_customer_id and o.status <> 'cancelled'
  group by 1
 )
 select m.m,coalesce(v.n,0)::bigint,coalesce(c.amount,0)::bigint,coalesce(c.n,0)::bigint
 from months m left join visits v on v.m=m.m left join cash c on c.m=m.m
 order by m.m desc;
end $$;
revoke all on function public.gs_cafe_customer_performance(bigint),
 public.gs_cafe_customer_monthly_trend(bigint,integer) from public,anon;
grant execute on function public.gs_cafe_customer_performance(bigint),
 public.gs_cafe_customer_monthly_trend(bigint,integer) to authenticated;
