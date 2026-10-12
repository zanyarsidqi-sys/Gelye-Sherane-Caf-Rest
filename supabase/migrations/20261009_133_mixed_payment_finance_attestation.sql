-- Upgrade 133: actual finance attestation for fully paid cash + independently
-- provider-verified card/online orders. Does NOT enable table release.
create table if not exists public.gs_mixed_payment_settlement_attestations (
 id bigint generated always as identity primary key,
 order_id bigint not null unique references public.gs_orders(id) on delete restrict,
 table_visit_id bigint not null references public.gs_table_visits(id),
 order_total_iqd bigint not null check(order_total_iqd>0),
 cash_iqd bigint not null check(cash_iqd>=0),
 verified_provider_iqd bigint not null check(verified_provider_iqd>0),
 provider_payment_count bigint not null check(provider_payment_count>0),
 attested_by uuid not null references auth.users(id),
 attested_at timestamptz not null default now(),
 check (order_total_iqd=cash_iqd+verified_provider_iqd)
);
alter table public.gs_mixed_payment_settlement_attestations enable row level security;
revoke all on public.gs_mixed_payment_settlement_attestations from public,anon,authenticated;
create or replace function public.gs_block_mixed_settlement_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Mixed payment attestations are immutable';end; $$;
drop trigger if exists gs_mixed_settlement_immutable
 on public.gs_mixed_payment_settlement_attestations;
create trigger gs_mixed_settlement_immutable before update or delete
 on public.gs_mixed_payment_settlement_attestations for each row
 execute function public.gs_block_mixed_settlement_mutation();

create or replace function public.gs_attest_mixed_order_settlement(p_order_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype;
 v_total bigint;v_cash bigint;v_provider bigint;v_count bigint;
 v_other bigint;v_id bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
  or not public.gs_can_access('invoices_payments','can_edit')
  or not exists(select 1 from public.gs_cash_correction_finance_reviewers
    where user_id=auth.uid() and enabled) then
  raise exception 'Provisioned finance reviewer, MFA and edit permission required';
 end if;
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found or v_order.table_visit_id is null
    or v_order.status='cancelled' then
  raise exception 'Eligible table order not found';end if;
 if not exists(select 1 from public.gs_table_visits
  where id=v_order.table_visit_id and status in ('active','cleaning')) then
  raise exception 'Visit is not active';end if;
 select id into v_id from public.gs_mixed_payment_settlement_attestations
  where order_id=p_order_id;
 if found then return v_id;end if;
 if exists(select 1 from public.gs_cash_only_settlement_attestations
  where order_id=p_order_id)
 or exists(select 1 from public.gs_cash_correction_postings where order_id=p_order_id)
 or exists(select 1 from public.gs_owner_guest_offers where order_id=p_order_id)
 or exists(select 1 from public.gs_table_bill_transfer_request_items i
   join public.gs_order_items oi on oi.id=i.order_item_id
   where oi.order_id=p_order_id)
 or exists(select 1 from public.gs_cash_payments c
   where c.order_id=p_order_id and c.collected_by=auth.uid()) then
  raise exception 'Conflicting settlement, correction, waiver, transfer or self-collected cash';
 end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
 from public.gs_order_items where order_id=p_order_id;
 select coalesce(sum(amount_iqd),0)::bigint into v_cash
 from public.gs_cash_payments where order_id=p_order_id;
 -- Count ONLY server-verified, ledger-posted provider payments with
 -- matching immutable inbox/evidence references. Never trust client claims.
 select coalesce(sum(l.amount_iqd),0)::bigint,count(*)::bigint
 into v_provider,v_count
 from public.gs_unified_payment_ledger l
 join public.gs_payment_verification_inbox i
  on l.source_system='verified_provider_event'
  and l.source_reference=i.id::text
 join public.gs_external_payment_evidence e on e.id=i.evidence_id
 where l.order_id=p_order_id and e.order_id=p_order_id
  and l.entry_type in ('card','online') and l.entry_type=e.method
  and l.direction='credit' and i.intake_status='verified_by_server'
  and l.verified_at=i.verified_at and i.reported_currency='IQD'
  and l.amount_iqd=i.reported_amount_iqd
  and l.amount_iqd=e.amount_iqd
  and i.provider_reference=e.external_reference;
 -- Any other ledger posting is a blocker, except exact cash mirrors.
 select count(*)::bigint into v_other
 from public.gs_unified_payment_ledger l
 where l.order_id=p_order_id and not (
   (l.source_system='verified_provider_event' and exists(
     select 1 from public.gs_payment_verification_inbox i
     join public.gs_external_payment_evidence e on e.id=i.evidence_id
     where i.id::text=l.source_reference and e.order_id=l.order_id
       and i.intake_status='verified_by_server' and l.entry_type=e.method
       and l.direction='credit' and l.verified_at=i.verified_at
       and i.reported_currency='IQD'
       and l.amount_iqd=i.reported_amount_iqd
       and l.amount_iqd=e.amount_iqd
       and i.provider_reference=e.external_reference))
   or (l.entry_type='cash' and l.direction='credit'
    and l.source_system='legacy_cash' and exists(
      select 1 from public.gs_cash_ledger_reconciliation_links x
      join public.gs_cash_payments c on c.id=x.legacy_cash_id
      where x.ledger_entry_id=l.id and c.order_id=l.order_id
        and c.amount_iqd=l.amount_iqd))
 );
 if v_other>0 then raise exception 'Unverified or conflicting ledger entries';end if;
 if exists(select 1 from public.gs_external_payment_evidence e
  where e.order_id=p_order_id and not exists(
    select 1 from public.gs_payment_verification_inbox i
    join public.gs_unified_payment_ledger l
      on l.source_system='verified_provider_event'
      and l.source_reference=i.id::text
    where i.evidence_id=e.id and i.intake_status='verified_by_server'
      and l.order_id=e.order_id and l.amount_iqd=e.amount_iqd
      and l.entry_type=e.method and l.direction='credit'
      and i.reported_currency='IQD')) then
  raise exception 'Unverified provider evidence remains';end if;
 if v_total<=0 or v_count=0 or v_provider<=0
   or v_total<>v_cash+v_provider then
  raise exception 'Verified cash and provider payments do not settle order';
 end if;
 insert into public.gs_mixed_payment_settlement_attestations(
  order_id,table_visit_id,order_total_iqd,cash_iqd,
  verified_provider_iqd,provider_payment_count,attested_by)
 values(p_order_id,v_order.table_visit_id,v_total,v_cash,
  v_provider,v_count,auth.uid()) returning id into v_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','mixed_payment_settlement_attested',
  p_order_id::text,jsonb_build_object('attestation_id',v_id,
    'cash_iqd',v_cash,'provider_iqd',v_provider,'checkout_allowed',false));
 return v_id;
end; $$;
revoke all on function public.gs_attest_mixed_order_settlement(bigint)
 from public,anon;
grant execute on function public.gs_attest_mixed_order_settlement(bigint)
 to authenticated;
