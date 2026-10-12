-- Upgrade 140: make mixed checkout fail closed against unverified finance state.
-- Additive migration; does not rewrite a previously applied migration.
-- No changes to the feature gate: release remains disabled by default.
create or replace function public.gs_mixed_checkout_financial_integrity(p_visit_id bigint)
returns table(order_id bigint,issue text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_view')
  or not public.gs_can_access('tables','can_view') then
  raise exception 'Finance and table review permissions required';
 end if;
 return query
 select o.id,'Conflicting cash and mixed attestations'::text
 from public.gs_orders o
 where o.table_visit_id=p_visit_id
  and exists(select 1 from public.gs_cash_only_settlement_attestations c
    where c.order_id=o.id)
  and exists(select 1 from public.gs_mixed_payment_settlement_attestations m
    where m.order_id=o.id)
 union all
 select o.id,'Mixed attestation total no longer matches order lines'::text
 from public.gs_orders o
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=o.id
 where o.table_visit_id=p_visit_id
 and m.order_total_iqd<>coalesce((
  select sum(i.line_total_iqd)::bigint from public.gs_order_items i
  where i.order_id=o.id),0)
 union all
 select o.id,'Mixed attestation cash no longer matches receipts'::text
 from public.gs_orders o
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=o.id
 where o.table_visit_id=p_visit_id
 and m.cash_iqd<>coalesce((
  select sum(c.amount_iqd)::bigint from public.gs_cash_payments c
  where c.order_id=o.id),0)
 union all
 select o.id,'Unverified or inconsistent electronic ledger entry'::text
 from public.gs_orders o
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=o.id
 where o.table_visit_id=p_visit_id
 and exists (
  select 1 from public.gs_unified_payment_ledger l
  where l.order_id=o.id and l.entry_type in ('card','online')
   and not exists(
    select 1 from public.gs_payment_verification_inbox v
    join public.gs_external_payment_evidence e on e.id=v.evidence_id
    where v.id::text=l.source_reference
     and l.source_system='verified_provider_event'
     and v.intake_status='verified_by_server'
     and v.verified_at=l.verified_at
     and v.reported_currency='IQD'
     and v.reported_amount_iqd=l.amount_iqd
     and v.provider_reference=e.external_reference
     and e.order_id=l.order_id and e.method=l.entry_type
     and e.amount_iqd=l.amount_iqd and l.direction='credit'
   )
 )
 union all
 select o.id,'Unposted external payment evidence'::text
 from public.gs_orders o
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=o.id
 where o.table_visit_id=p_visit_id
 and exists(
  select 1 from public.gs_external_payment_evidence e
  where e.order_id=o.id and not exists(
   select 1 from public.gs_payment_verification_inbox v
   join public.gs_unified_payment_ledger l
    on l.source_system='verified_provider_event'
    and l.source_reference=v.id::text
   where v.evidence_id=e.id and v.intake_status='verified_by_server'
    and l.order_id=e.order_id and l.entry_type=e.method
    and l.amount_iqd=e.amount_iqd and l.direction='credit'
  )
 );
end; $$;
revoke all on function public.gs_mixed_checkout_financial_integrity(bigint)
 from public,anon;
grant execute on function public.gs_mixed_checkout_financial_integrity(bigint)
 to authenticated;
