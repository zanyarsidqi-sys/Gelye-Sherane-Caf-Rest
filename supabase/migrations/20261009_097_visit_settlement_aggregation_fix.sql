-- Upgrade 97: fix visit settlement aggregation loop and fail-closed diagnostics.
-- The old function reused v_rec for the cursor and SELECT INTO, which could
-- overwrite its order identifier. Use separate typed loop and summary records.
create or replace function public.gs_visit_settlement_gate(p_visit_id bigint)
returns table(visit_id bigint,table_id bigint,visit_status text,
 order_count bigint,order_total_iqd bigint,provisional_net_iqd bigint,
 reconciliation_exceptions bigint,unlinked_historical_orders bigint,
 all_orders_financially_verified boolean,checkout_allowed boolean,
 blocking_reason text)
language plpgsql stable security definer set search_path='' as $$
declare
 v public.gs_table_visits%rowtype;
 v_order record;
 v_summary record;
 v_count bigint:=0;v_total bigint:=0;v_net bigint:=0;
 v_exc bigint:=0;v_unlinked bigint:=0;
begin
 if auth.uid() is null or not (
   public.gs_can_access('invoices_payments','can_view') or
   public.gs_can_access('payments_management','can_view'))
   or not public.gs_can_access('tables','can_view') then
  raise exception 'Visit settlement inspection permission denied';
 end if;
 if p_visit_id is null then raise exception 'Visit ID required'; end if;
 select * into v from public.gs_table_visits where id=p_visit_id;
 if not found then raise exception 'Visit not found'; end if;
 select count(*) into v_unlinked from public.gs_orders o
 join public.gs_cafe_tables t on t.id=v.table_id
 where o.table_visit_id is null and o.is_motel=false
   and o.destination=t.table_number::text and o.status<>'cancelled';
 for v_order in
  select o.id from public.gs_orders o
  where o.table_visit_id=p_visit_id and o.status<>'cancelled'
  order by o.id
 loop
  select * into v_summary
  from public.gs_dashboard_payment_reconciliation_summary(v_order.id);
  if not found then raise exception 'Reconciliation summary missing for order %',v_order.id; end if;
  v_count:=v_count+1;
  v_total:=v_total+coalesce(v_summary.order_total_iqd,0);
  v_net:=v_net+coalesce(v_summary.provisional_net_iqd,0);
  v_exc:=v_exc+coalesce(v_summary.reconciliation_exceptions,0);
 end loop;
 return query select v.id,v.table_id,v.status,v_count,v_total,v_net,
  v_exc,v_unlinked,false,false,
  case
   when v.status<>'active' then 'BLOCKED: visit is not active'
   when v_count=0 then 'BLOCKED: no non-cancelled visit-linked orders; cannot certify checkout'
   when v_unlinked>0 then 'BLOCKED: historical unlinked orders require manual reconciliation'
   when v_exc>0 then 'BLOCKED: payment reconciliation exceptions'
   when v_net<>v_total then 'BLOCKED: provisional visit balance not zero'
   else 'BLOCKED: authoritative settlement and departure/cleaning verification not implemented'
  end::text;
end; $$;
revoke all on function public.gs_visit_settlement_gate(bigint) from public,anon;
grant execute on function public.gs_visit_settlement_gate(bigint) to authenticated;
-- Always returns all_orders_financially_verified=false and checkout_allowed=false.
