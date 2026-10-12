-- Upgrade 208: period-scoped customer rankings. Dates are inclusive-start/exclusive-end
-- in the cafe's local time zone (Asia/Baghdad). Do not infer non-cash spend.
create or replace function public.gs_cafe_customer_period_rankings(
 p_month date, p_rank_by text default 'spend')
returns table(customer_id bigint, customer_name text, visit_count bigint,
 cash_spent_iqd bigint, settled_orders bigint, last_activity timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare v_start timestamptz; v_end timestamptz;
begin
 if auth.uid() is null or not public.gs_can_access('customers','can_view') then
  raise exception 'Customer view permission required'; end if;
 if p_month is null or p_month <> date_trunc('month',p_month::timestamp)::date
    or p_month < date '2000-01-01' or p_month > (now() at time zone 'Asia/Baghdad')::date + interval '12 months' then
  raise exception 'Invalid reporting month'; end if;
 if p_rank_by not in ('spend','visits') then raise exception 'Invalid ranking'; end if;
 v_start := p_month::timestamp at time zone 'Asia/Baghdad';
 v_end := (p_month::timestamp + interval '1 month') at time zone 'Asia/Baghdad';
 return query
 with visit_totals as (
  select v.customer_id, count(*)::bigint as n, max(v.visited_at) as last_at
  from public.gs_cafe_customer_visits v
  where v.visited_at >= v_start and v.visited_at < v_end
  group by v.customer_id
 ), uniquely_linked as (
  select v.table_visit_id,min(v.customer_id) as customer_id
  from public.gs_cafe_customer_visits v where v.table_visit_id is not null
  group by v.table_visit_id having count(distinct v.customer_id)=1
 ), spend_totals as (
  select l.customer_id,sum(a.collected_cash_iqd)::bigint as amount,
   count(*)::bigint as n,max(a.attested_at) as last_at
  from public.gs_cash_only_settlement_attestations a
  join public.gs_orders o on o.id=a.order_id and o.table_visit_id=a.table_visit_id
  join uniquely_linked l on l.table_visit_id=a.table_visit_id
  where a.attested_at >= v_start and a.attested_at < v_end
    and o.status <> 'cancelled'
  group by l.customer_id
 )
 select c.id,c.full_name,coalesce(v.n,0)::bigint,
  coalesce(s.amount,0)::bigint,coalesce(s.n,0)::bigint,
  greatest(v.last_at,s.last_at)
 from public.gs_cafe_customer_profiles c
 left join visit_totals v on v.customer_id=c.id
 left join spend_totals s on s.customer_id=c.id
 where v.n is not null or s.n is not null
 order by case when p_rank_by='spend' then coalesce(s.amount,0) end desc nulls last,
          case when p_rank_by='visits' then coalesce(v.n,0) end desc nulls last,
          coalesce(s.amount,0) desc,coalesce(v.n,0) desc,c.full_name
 limit 2000;
end $$;
revoke all on function public.gs_cafe_customer_period_rankings(date,text) from public,anon;
grant execute on function public.gs_cafe_customer_period_rankings(date,text) to authenticated;
