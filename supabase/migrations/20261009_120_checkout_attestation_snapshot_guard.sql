-- Upgrade 115: narrowly scoped REAL checkout for independently attested cash-only visits.
-- Excludes mixed/credit/provider/owner-offer/corrected orders by construction.
-- This migration requires staging review of the deployed table schema and
-- triggers before deployment. Never use the legacy release RPC.
create or replace function public.gs_release_cash_only_table_visit(p_visit_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_table_id bigint;v_table public.gs_cafe_tables%rowtype;
 v_visit public.gs_table_visits%rowtype;v_order_count bigint;
 v_attested_count bigint;v_physical record;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit')
    or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Checkout permission denied';
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
       or exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id)
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
     or exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=o.id)
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
