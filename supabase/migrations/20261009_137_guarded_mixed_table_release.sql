-- Upgrade 137: protected mixed-payment table release, feature-disabled by default.
-- Enable ONLY after provider integration and staging race/security testing.
create table if not exists public.gs_mixed_checkout_feature_gate (
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 enabled_by uuid references auth.users(id),
 enabled_at timestamptz,
 reason text not null default 'Pending provider integration and staging validation'
);
insert into public.gs_mixed_checkout_feature_gate(singleton,enabled)
 values(true,false) on conflict(singleton) do nothing;
alter table public.gs_mixed_checkout_feature_gate enable row level security;
revoke all on public.gs_mixed_checkout_feature_gate from public,anon,authenticated;

create or replace function public.gs_release_mixed_payment_table_visit(p_visit_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_table_id bigint;v_table public.gs_cafe_tables%rowtype;
 v_visit public.gs_table_visits%rowtype;v_count bigint;
 v_cash_count bigint;v_mixed_count bigint;v_physical record;
 v_order public.gs_orders%rowtype;v_a public.gs_mixed_payment_settlement_attestations%rowtype;
 v_total bigint;v_cash bigint;v_provider bigint;v_providers bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
  or not public.gs_can_access('tables','can_edit')
  or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'MFA and checkout permissions required';
 end if;
 if not exists(select 1 from public.gs_mixed_checkout_feature_gate
   where singleton and enabled) then
  raise exception 'Mixed-payment checkout is disabled pending integration testing';
 end if;
 select table_id into v_table_id from public.gs_table_visits where id=p_visit_id;
 if v_table_id is null then raise exception 'Visit not found';end if;
 select * into v_table from public.gs_cafe_tables where id=v_table_id for update;
 select * into v_visit from public.gs_table_visits where id=p_visit_id for update;
 if not found or v_visit.table_id<>v_table.id
  or v_visit.status not in ('active','cleaning') or not v_table.occupied then
  raise exception 'Visit/table not eligible';end if;
 if exists(select 1 from public.gs_table_visits x
   where x.table_id=v_table_id and x.id<>p_visit_id and x.status<>'closed') then
  raise exception 'Conflicting open visit';end if;
 perform 1 from public.gs_orders where table_visit_id=p_visit_id
  order by id for update;
 select count(*) into v_count from public.gs_orders
  where table_visit_id=p_visit_id and status<>'cancelled';
 if v_count=0 then raise exception 'No eligible orders';end if;
 select count(*) into v_cash_count from public.gs_orders o
 join public.gs_cash_only_settlement_attestations a
 on a.order_id=o.id and a.table_visit_id=p_visit_id
 where o.table_visit_id=p_visit_id and o.status<>'cancelled';
 select count(*) into v_mixed_count from public.gs_orders o
 join public.gs_mixed_payment_settlement_attestations a
 on a.order_id=o.id and a.table_visit_id=p_visit_id
 where o.table_visit_id=p_visit_id and o.status<>'cancelled'
 and not exists(select 1 from public.gs_cash_only_settlement_attestations c
 where c.order_id=o.id);
 if v_mixed_count<1 or v_count<>v_cash_count+v_mixed_count then
  raise exception 'Every order needs exactly one settlement attestation';end if;
 if exists(select 1 from public.gs_orders o
 where o.table_visit_id=p_visit_id and o.status='cancelled'
 and (exists(select 1 from public.gs_cash_payments c where c.order_id=o.id)
 or exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id)
 or exists(select 1 from public.gs_external_payment_evidence e where e.order_id=o.id)))
 then raise exception 'Cancelled order contains financial evidence';end if;
 -- Independently recalculate attested mixed amounts under order locks.
 for v_order in select * from public.gs_orders
  where table_visit_id=p_visit_id and status<>'cancelled' order by id
 loop
  select * into v_a from public.gs_mixed_payment_settlement_attestations
   where order_id=v_order.id;
  if found then
   select coalesce(sum(line_total_iqd),0)::bigint into v_total
    from public.gs_order_items where order_id=v_order.id;
   select coalesce(sum(amount_iqd),0)::bigint into v_cash
    from public.gs_cash_payments where order_id=v_order.id;
   select coalesce(sum(l.amount_iqd),0)::bigint,count(*)::bigint
    into v_provider,v_providers
    from public.gs_unified_payment_ledger l
    join public.gs_payment_verification_inbox i
      on l.source_system='verified_provider_event'
      and l.source_reference=i.id::text
    join public.gs_external_payment_evidence e on e.id=i.evidence_id
    where l.order_id=v_order.id and e.order_id=v_order.id
    and i.intake_status='verified_by_server' and l.direction='credit'
    and l.entry_type=e.method and l.entry_type in ('card','online')
    and l.verified_at=i.verified_at and i.reported_currency='IQD'
    and l.amount_iqd=e.amount_iqd and l.amount_iqd=i.reported_amount_iqd
    and i.provider_reference=e.external_reference;
   if v_total<>v_a.order_total_iqd or v_cash<>v_a.cash_iqd
    or v_provider<>v_a.verified_provider_iqd
    or v_providers<>v_a.provider_payment_count
    or v_total<>v_cash+v_provider then
    raise exception 'Mixed settlement changed after attestation';end if;
  end if;
 end loop;
 -- Fail closed on any additional payment/evidence or accounting event
 -- not represented by the attested mixed settlement. Prior attestation
 -- alone is insufficient if a separate service-role writer bypasses guards.
 if exists (
  select 1 from public.gs_orders o
  join public.gs_mixed_payment_settlement_attestations a on a.order_id=o.id
  where o.table_visit_id=p_visit_id and o.status<>'cancelled'
   and (
    exists(select 1 from public.gs_cash_correction_postings c
      where c.order_id=o.id)
    or exists(select 1 from public.gs_owner_guest_offers w
      where w.order_id=o.id)
    or exists(select 1 from public.gs_external_payment_evidence e
      where e.order_id=o.id and not exists(
       select 1 from public.gs_payment_verification_inbox i
       join public.gs_unified_payment_ledger l
        on l.source_system='verified_provider_event'
         and l.source_reference=i.id::text
       where i.evidence_id=e.id and i.intake_status='verified_by_server'
        and l.order_id=e.order_id and l.entry_type=e.method
        and l.direction='credit' and l.amount_iqd=e.amount_iqd
        and i.reported_currency='IQD'))
    or exists(select 1 from public.gs_unified_payment_ledger l
      where l.order_id=o.id and not (
       (l.source_system='verified_provider_event' and exists(
        select 1 from public.gs_payment_verification_inbox i
        join public.gs_external_payment_evidence e on e.id=i.evidence_id
        where i.id::text=l.source_reference and e.order_id=l.order_id
         and i.intake_status='verified_by_server'
         and l.entry_type=e.method and l.direction='credit'
         and l.verified_at=i.verified_at and l.amount_iqd=e.amount_iqd
         and i.reported_amount_iqd=l.amount_iqd
         and i.reported_currency='IQD'
         and i.provider_reference=e.external_reference))
       or (l.entry_type='cash' and l.direction='credit'
        and l.source_system='legacy_cash' and exists(
         select 1 from public.gs_cash_ledger_reconciliation_links x
         join public.gs_cash_payments c on c.id=x.legacy_cash_id
         where x.ledger_entry_id=l.id and c.order_id=l.order_id
          and c.amount_iqd=l.amount_iqd))
      ))
   )
 ) then
  raise exception 'Unverified, unaccounted or corrected financial event blocks release';
 end if;
 select * into v_physical from public.gs_visit_physical_checkout_status(p_visit_id);
 if v_physical.physical_ready is distinct from true then
  raise exception 'Physical checkout incomplete: %',
    coalesce(v_physical.blocking_reason,'unknown');end if;
 update public.gs_table_visits set status='closed',
  closed_at=now(),closed_by=auth.uid() where id=p_visit_id;
 update public.gs_cafe_tables set occupied=false,guests=0,
  tourism_mode=false,cleaning_needed=false,guests_departed_at=null,
  updated_at=now(),updated_by=auth.uid() where id=v_table_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'tables','mixed_payment_visit_released',p_visit_id::text,
 jsonb_build_object('table_id',v_table_id,'cash_orders',v_cash_count,
 'mixed_orders',v_mixed_count,'physical_tasks_complete',true));
 return v_table_id;
end; $$;
revoke all on function public.gs_release_mixed_payment_table_visit(bigint)
 from public,anon;
grant execute on function public.gs_release_mixed_payment_table_visit(bigint)
 to authenticated;
