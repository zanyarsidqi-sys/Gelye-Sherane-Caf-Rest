-- Upgrade 360: staff-only motel food staging ledger reconciliation.
-- Read-only: does not post payments, issue invoices, or change charges.
create or replace function public.gs_staff_motel_food_ledger_reconciliation()
returns table(delivered_orders bigint, ledger_entries bigint, missing_entries bigint,
 amount_mismatches bigint, orphan_or_non_delivered_entries bigint,
 delivered_total_iqd numeric, staged_total_iqd numeric)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Not authorized';
 end if;
 return query
 with delivered as (
  select o.id,o.total_iqd from public.gs_motel_guest_food_requests o
  where o.status='delivered'
 ), ledger as (
  select l.request_id,l.amount_iqd from public.gs_motel_food_billing_ledger l
 )
 select
  (select count(*) from delivered),
  (select count(*) from ledger),
  (select count(*) from delivered d left join ledger l on l.request_id=d.id where l.request_id is null),
  (select count(*) from delivered d join ledger l on l.request_id=d.id where d.total_iqd<>l.amount_iqd),
  (select count(*) from ledger l left join delivered d on d.id=l.request_id where d.id is null),
  (select coalesce(sum(d.total_iqd),0)::numeric from delivered d),
  (select coalesce(sum(l.amount_iqd),0)::numeric from ledger l);
end; $$;
revoke all on function public.gs_staff_motel_food_ledger_reconciliation() from public;
grant execute on function public.gs_staff_motel_food_ledger_reconciliation() to authenticated;
