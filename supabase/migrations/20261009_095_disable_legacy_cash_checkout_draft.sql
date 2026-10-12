-- Upgrade 95: close legacy cash-only checkout/departure bypass.
-- Upgrade 45 treated sums of legacy cash receipts as final settlement and
-- selected historical orders by table number. That is insufficient once
-- visits, unified ledger, credit, external payments and owner offers exist.
-- Until authoritative settlement is implemented, refuse to mark departure
-- and create cleaning tasks through this legacy entry point.
create or replace function public.gs_mark_table_departed_for_cleaning(
 p_table_id bigint, p_shisha_collection_confirmed boolean default false
) returns table(cleaning_task_id bigint, shisha_task_id bigint)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit')
  or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Checkout permission denied';
 end if;
 raise exception using errcode='P0001',
  message='Legacy cash-only checkout is disabled until authoritative visit-level settlement is implemented';
end; $$;
revoke all on function public.gs_mark_table_departed_for_cleaning(bigint,boolean)
 from public,anon;
grant execute on function public.gs_mark_table_departed_for_cleaning(bigint,boolean)
 to authenticated;
-- No changes to existing visits, tables, receipts, orders, or tasks.
