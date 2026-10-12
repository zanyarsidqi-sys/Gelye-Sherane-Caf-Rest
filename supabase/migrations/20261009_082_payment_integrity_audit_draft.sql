-- Upgrade 82: financial integrity reconciliation audit (READ ONLY).
-- This does not certify settlement, post money, or enable bill transfers.
create or replace function public.gs_dashboard_payment_integrity_audit(p_order_id bigint)
returns table(
  order_id bigint, order_total_iqd bigint, legacy_cash_iqd bigint,
  ledger_net_iqd bigint, unlinked_cash_receipts bigint,
  unmatched_ledger_cash_entries bigint, invalid_crosswalks bigint,
  pending_external_evidence bigint, pending_owner_offers bigint,
  transfer_execution_safe boolean, findings text[]
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_total bigint; v_cash bigint; v_ledger bigint;
 v_unlinked bigint; v_unmatched bigint; v_invalid bigint;
 v_external bigint; v_offers bigint;
 v_findings text[]:=array[]::text[];
begin
 if auth.uid() is null or not (
   public.gs_can_access('invoices_payments','can_view') or
   public.gs_can_access('payments_management','can_view')) then
   raise exception 'Payment audit access denied';
 end if;
 if p_order_id is null or not exists (
   select 1 from public.gs_orders o where o.id=p_order_id) then
   raise exception 'Order not found';
 end if;
 select coalesce(sum(i.line_total_iqd),0)::bigint into v_total
 from public.gs_order_items i where i.order_id=p_order_id;
 select coalesce(sum(c.amount_iqd),0)::bigint into v_cash
 from public.gs_cash_payments c where c.order_id=p_order_id;
 select coalesce(sum(case when l.direction='credit' then l.amount_iqd
   else -l.amount_iqd end),0)::bigint into v_ledger
 from public.gs_unified_payment_ledger l where l.order_id=p_order_id;
 select count(*)::bigint into v_unlinked from public.gs_cash_payments c
 left join public.gs_cash_ledger_reconciliation_links x
   on x.legacy_cash_id=c.id
 where c.order_id=p_order_id and x.legacy_cash_id is null;
 select count(*)::bigint into v_unmatched
 from public.gs_unified_payment_ledger l
 left join public.gs_cash_ledger_reconciliation_links x
   on x.ledger_entry_id=l.id
 where l.order_id=p_order_id and l.entry_type='cash'
   and l.direction='credit' and x.ledger_entry_id is null;
 select count(*)::bigint into v_invalid
 from public.gs_cash_ledger_reconciliation_links x
 join public.gs_cash_payments c on c.id=x.legacy_cash_id
 join public.gs_unified_payment_ledger l on l.id=x.ledger_entry_id
 where (c.order_id=p_order_id or l.order_id=p_order_id)
 and (c.order_id is distinct from l.order_id
   or c.amount_iqd is distinct from l.amount_iqd
   or l.entry_type<>'cash' or l.direction<>'credit'
   or l.source_system<>'legacy_cash');
 select count(*)::bigint into v_external
 from public.gs_external_payment_evidence e
 where e.order_id=p_order_id and e.verification_status<>'verified';
 select count(*)::bigint into v_offers
 from public.gs_owner_guest_offers g
 where g.order_id=p_order_id and g.status in ('pending','verified');
 if v_unlinked>0 then v_findings:=array_append(v_findings,'unlinked_legacy_cash'); end if;
 if v_unmatched>0 then v_findings:=array_append(v_findings,'unmatched_ledger_cash'); end if;
 if v_invalid>0 then v_findings:=array_append(v_findings,'crosswalk_mismatch'); end if;
 if v_external>0 then v_findings:=array_append(v_findings,'external_evidence_not_verified'); end if;
 if v_offers>0 then v_findings:=array_append(v_findings,'owner_offer_not_settled'); end if;
 if v_cash>v_total then v_findings:=array_append(v_findings,'legacy_cash_exceeds_order_total'); end if;
 if v_ledger>v_total then v_findings:=array_append(v_findings,'ledger_net_exceeds_order_total'); end if;
 v_findings:=array_append(v_findings,'authoritative_settlement_not_implemented');
 return query select p_order_id,v_total,v_cash,v_ledger,v_unlinked,
   v_unmatched,v_invalid,v_external,v_offers,false,v_findings;
end; $$;
revoke all on function public.gs_dashboard_payment_integrity_audit(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_payment_integrity_audit(bigint)
 to authenticated;
-- The false transfer_execution_safe value is intentional: this function
-- must never be used as payment verification or transfer authorization.
