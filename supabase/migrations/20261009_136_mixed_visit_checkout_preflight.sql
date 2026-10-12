-- Upgrade 136: visit-wide mixed-payment checkout preflight.
-- Read-only by design. Does not close a visit, release a table or move money.
create or replace function public.gs_mixed_visit_checkout_preflight(p_visit_id bigint)
returns table(
 visit_id bigint,table_id bigint,active_orders bigint,
 cash_attested_orders bigint,mixed_attested_orders bigint,
 unapproved_orders bigint,financial_evidence_on_cancelled boolean,
 physical_ready boolean,blocking_reason text,eligible_for_future_release boolean
) language plpgsql security definer set search_path='' as $$
declare v_visit public.gs_table_visits%rowtype;
 v_physical record;v_total bigint;v_cash bigint;v_mixed bigint;
 v_unapproved bigint;v_cancelled boolean;v_reason text;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view')
   or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Checkout review permission denied';
 end if;
 select * into v_visit from public.gs_table_visits where id=p_visit_id;
 if not found then raise exception 'Visit not found';end if;
 select count(*) into v_total from public.gs_orders o
  where o.table_visit_id=p_visit_id and o.status<>'cancelled';
 select count(*) into v_cash from public.gs_orders o
  join public.gs_cash_only_settlement_attestations a
   on a.order_id=o.id and a.table_visit_id=p_visit_id
  where o.table_visit_id=p_visit_id and o.status<>'cancelled';
 select count(*) into v_mixed from public.gs_orders o
  join public.gs_mixed_payment_settlement_attestations a
   on a.order_id=o.id and a.table_visit_id=p_visit_id
  where o.table_visit_id=p_visit_id and o.status<>'cancelled'
    and not exists(select 1 from public.gs_cash_only_settlement_attestations c
      where c.order_id=o.id);
 v_unapproved:=v_total-v_cash-v_mixed;
 select exists(select 1 from public.gs_orders o
  where o.table_visit_id=p_visit_id and o.status='cancelled'
   and (exists(select 1 from public.gs_cash_payments c where c.order_id=o.id)
    or exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id)
    or exists(select 1 from public.gs_external_payment_evidence e where e.order_id=o.id)))
 into v_cancelled;
 select * into v_physical from public.gs_visit_physical_checkout_status(p_visit_id);
 v_reason:=case
  when v_visit.status not in ('active','cleaning') then 'Visit not open'
  when not exists(select 1 from public.gs_cafe_tables t
     where t.id=v_visit.table_id and t.occupied) then 'Table not occupied'
  when exists(select 1 from public.gs_table_visits x
     where x.table_id=v_visit.table_id and x.id<>p_visit_id and x.status<>'closed')
     then 'Conflicting open visit'
  when v_total=0 then 'No eligible orders'
  when v_cancelled then 'Cancelled order has financial evidence'
  when v_unapproved<>0 then 'Some orders lack independent settlement attestation'
  when v_physical.physical_ready is distinct from true
     then coalesce(v_physical.blocking_reason,'Physical checkout incomplete')
  else null end;
 return query select p_visit_id,v_visit.table_id,v_total,v_cash,v_mixed,
  v_unapproved,v_cancelled,coalesce(v_physical.physical_ready,false),
  v_reason,(v_reason is null and v_mixed>0);
end; $$;
revoke all on function public.gs_mixed_visit_checkout_preflight(bigint) from public,anon;
grant execute on function public.gs_mixed_visit_checkout_preflight(bigint)
 to authenticated;
