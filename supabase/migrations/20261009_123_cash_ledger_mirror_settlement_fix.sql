-- Upgrade 123: reconcile legitimate cash receipt ledger mirrors in both
-- finance attestation and checkout; prevent false mixed-payment rejection.
-- Replaces both RPCs with their reviewed source definitions.
create or replace function public.gs_attest_cash_only_order_settlement(p_order_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype;
 v_total bigint;v_cash bigint;v_receipts bigint;v_existing bigint;
 v_id bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
  or not public.gs_can_access('invoices_payments','can_edit')
  or not exists(select 1 from public.gs_cash_correction_finance_reviewers
    where user_id=auth.uid() and enabled) then
  raise exception 'Provisioned finance reviewer, MFA and edit permission required';
 end if;
 if p_order_id is null then raise exception 'Order required'; end if;
 -- Same order lock as cash-collection writer, so amount is stable here.
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found or v_order.table_visit_id is null or v_order.status='cancelled' then
  raise exception 'Eligible table order not found'; end if;
 select id into v_existing from public.gs_cash_only_settlement_attestations
  where order_id=p_order_id;
 if found then return v_existing; end if;
 if not exists(select 1 from public.gs_table_visits v
    where v.id=v_order.table_visit_id and v.status in ('active','cleaning')) then
  raise exception 'No valid open table visit'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
  from public.gs_order_items where order_id=p_order_id;
 select coalesce(sum(amount_iqd),0)::bigint,count(*)::bigint
  into v_cash,v_receipts from public.gs_cash_payments where order_id=p_order_id;
 if v_total<=0 or v_cash<>v_total or v_receipts=0 then
  raise exception 'Cash receipts do not exactly match the order total'; end if;
 -- Deliberately reject mixed-method and corrected orders rather than infer
 -- settlement from provisional ledger or unverifiable physical refunds.
 if exists(select 1 from public.gs_cash_correction_postings where order_id=p_order_id)
  or exists (
    select 1 from public.gs_unified_payment_ledger l
    where l.order_id=p_order_id and not exists (
      select 1 from public.gs_cash_ledger_reconciliation_links x
      join public.gs_cash_payments c on c.id=x.legacy_cash_id
      where x.ledger_entry_id=l.id and c.order_id=p_order_id
        and l.entry_type='cash' and l.direction='credit'
        and l.source_system='legacy_cash'
        and l.amount_iqd=c.amount_iqd
    )
  )
  or exists(select 1 from public.gs_external_payment_evidence where order_id=p_order_id)
  or exists(select 1 from public.gs_owner_guest_offers where order_id=p_order_id)
  or exists(select 1 from public.gs_table_bill_transfer_request_items i
    join public.gs_order_items oi on oi.id=i.order_item_id
    where oi.order_id=p_order_id)
  or exists(select 1 from public.gs_cash_payments c
    where c.order_id=p_order_id and c.collected_by=auth.uid()) then
  raise exception 'Mixed, corrected, transferred or self-collected order cannot be attested';
 end if;
 insert into public.gs_cash_only_settlement_attestations
  (order_id,table_visit_id,order_total_iqd,collected_cash_iqd,receipt_count,attested_by)
 values(p_order_id,v_order.table_visit_id,v_total,v_cash,v_receipts,auth.uid())
 returning id into v_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','cash_only_settlement_attested',
  p_order_id::text,jsonb_build_object('attestation_id',v_id,
  'cash_iqd',v_cash,'checkout_allowed',false));
 return v_id;
end; $$;
revoke all on function public.gs_attest_cash_only_order_settlement(bigint) from public,anon;
grant execute on function public.gs_attest_cash_only_order_settlement(bigint) to authenticated;

create or replace function public.gs_release_cash_only_table_visit(p_visit_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_table_id bigint;v_table public.gs_cafe_tables%rowtype;
 v_visit public.gs_table_visits%rowtype;v_order_count bigint;
 v_attested_count bigint;v_physical record;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
    or not public.gs_can_access('tables','can_edit')
    or not public.gs_can_access('invoices_payments','can_edit')
    or not exists (
      select 1 from public.gs_cash_correction_finance_reviewers r
      where r.user_id=auth.uid() and r.enabled
    ) then
  raise exception 'Checkout requires MFA and provisioned finance reviewer permissions';
 end if;
 if p_visit_id is null then raise exception 'Visit required';end if;
 -- Lock table first, then visit and orders. Serialize against visit opening.
 select table_id into v_table_id from public.gs_table_visits where id=p_visit_id;
 if v_table_id is null then raise exception 'Visit not found';end if;
 select * into v_table from public.gs_cafe_tables where id=v_table_id for update;
 select * into v_visit from public.gs_table_visits where id=p_visit_id for update;
 if not found or v_visit.table_id<>v_table.id
    or v_visit.status not in ('active','cleaning') or not v_table.occupied then
  raise exception 'Visit/table is not eligible for checkout';end if;
 if exists(select 1 from public.gs_table_visits x
  where x.table_id=v_table.id and x.id<>p_visit_id and x.status<>'closed') then
  raise exception 'Conflicting open visit';end if;
 -- Order rows locked before comparing attestations. Attestation writer
 -- serializes on the same order rows. All noncancelled orders must be attested.
 perform 1 from public.gs_orders o where o.table_visit_id=p_visit_id
  and o.status<>'cancelled' order by o.id for update;
 select count(*) into v_order_count from public.gs_orders o
  where o.table_visit_id=p_visit_id and o.status<>'cancelled';
 if v_order_count=0 then raise exception 'Visit has no eligible paid orders';end if;
 select count(*) into v_attested_count from public.gs_orders o
  join public.gs_cash_only_settlement_attestations a
    on a.order_id=o.id and a.table_visit_id=p_visit_id
  where o.table_visit_id=p_visit_id and o.status<>'cancelled';
 if v_order_count<>v_attested_count then
  raise exception 'Every active visit order requires independent cash-only attestation';
 end if;
 -- Separation of duties: checkout approver must not be the same
 -- reviewer who attested any order in this visit.
 if exists (
   select 1 from public.gs_cash_only_settlement_attestations a
   where a.table_visit_id=p_visit_id and a.attested_by=auth.uid()
 ) then raise exception 'Checkout must be performed by a different finance reviewer';
 end if;
 -- Recheck the attestation snapshot under the locked order rows. Presence
 -- of an attestation alone is insufficient for authoritative settlement.
 if exists (
   select 1 from public.gs_orders o
   join public.gs_cash_only_settlement_attestations a
     on a.order_id=o.id and a.table_visit_id=p_visit_id
   where o.table_visit_id=p_visit_id and o.status<>'cancelled'
     and (a.order_total_iqd is distinct from
           (select coalesce(sum(i.line_total_iqd),0)::bigint
              from public.gs_order_items i where i.order_id=o.id)
       or a.collected_cash_iqd is distinct from
           (select coalesce(sum(c.amount_iqd),0)::bigint
              from public.gs_cash_payments c where c.order_id=o.id)
       or a.receipt_count is distinct from
           (select count(*) from public.gs_cash_payments c where c.order_id=o.id)
       or exists(
         select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id
           and not exists (
             select 1 from public.gs_cash_ledger_reconciliation_links x
             join public.gs_cash_payments c on c.id=x.legacy_cash_id
             where x.ledger_entry_id=l.id and c.order_id=o.id
               and l.entry_type='cash' and l.direction='credit'
               and l.source_system='legacy_cash'
               and l.amount_iqd=c.amount_iqd
           )
       )
       or exists(select 1 from public.gs_cash_correction_postings p where p.order_id=o.id)
       or exists(select 1 from public.gs_external_payment_evidence e where e.order_id=o.id)
       or exists(select 1 from public.gs_owner_guest_offers g where g.order_id=o.id)
     )
 ) then
   raise exception 'Settlement attestation no longer matches order evidence';
 end if;
 -- A legacy order addressed to the same physical table but lacking a visit
 -- must not be silently left unpaid when the table becomes available.
 if exists (
   select 1 from public.gs_orders o
   where o.table_visit_id is null and o.is_motel=false
     and o.destination=v_table.table_number::text
     and o.status<>'cancelled'
 ) then
   raise exception 'Unlinked legacy table order requires manual reconciliation';
 end if;
 -- Cancelled orders are excluded only when they have no money/evidence.
 if exists(select 1 from public.gs_orders o where o.table_visit_id=p_visit_id
   and o.status='cancelled' and (
     exists(select 1 from public.gs_cash_payments c where c.order_id=o.id)
     or exists(
         select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id
           and not exists (
             select 1 from public.gs_cash_ledger_reconciliation_links x
             join public.gs_cash_payments c on c.id=x.legacy_cash_id
             where x.ledger_entry_id=l.id and c.order_id=o.id
               and l.entry_type='cash' and l.direction='credit'
               and l.source_system='legacy_cash'
               and l.amount_iqd=c.amount_iqd
           )
       )
     or exists(select 1 from public.gs_external_payment_evidence e where e.order_id=o.id)
   )) then raise exception 'Cancelled visit order has financial evidence';end if;
 select * into v_physical from public.gs_visit_physical_checkout_status(p_visit_id);
 if v_physical.physical_ready is distinct from true then
  raise exception 'Physical checkout incomplete: %',coalesce(v_physical.blocking_reason,'unknown');
 end if;
 -- Do not modify attested orders; they are intentionally immutable.
 update public.gs_table_visits set status='closed',closed_at=now(),closed_by=auth.uid()
  where id=p_visit_id;
 update public.gs_cafe_tables set occupied=false,guests=0,
  tourism_mode=false,cleaning_needed=false,guests_departed_at=null,
  updated_at=now(),updated_by=auth.uid() where id=v_table.id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'tables','cash_only_visit_released',p_visit_id::text,
  jsonb_build_object('table_id',v_table.id,'attested_orders',v_attested_count,
    'cash_only',true,'physical_tasks_complete',true));
 return v_table.id;
end; $$;
revoke all on function public.gs_release_cash_only_table_visit(bigint) from public,anon;
grant execute on function public.gs_release_cash_only_table_visit(bigint) to authenticated;
