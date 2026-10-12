-- Upgrade 63: per-transfer financial allocation preflight (DRAFT).
-- Read-only; NEVER grants permission to apply a transfer.
-- Older table-moving RPC updates historical destination strings without
-- visit accounting; disable its authenticated execution pending replacement.
revoke execute on function public.gs_transfer_cafe_table(integer,integer)
 from public,anon,authenticated;

create or replace function public.gs_table_transfer_financial_preflight(p_request_id bigint)
returns table (
 transfer_request_id bigint, order_item_id bigint, source_order_id bigint,
 requested_quantity integer, unit_price_iqd bigint,
 requested_value_iqd bigint, source_order_total_iqd bigint,
 recorded_cash_iqd bigint, recorded_verified_external_iqd bigint,
 external_evidence_count bigint, owner_offer_count bigint,
 active_overlap_count bigint, ready_to_apply boolean, blocker_reason text
)
language plpgsql stable security definer set search_path='' as $$
declare v_request public.gs_table_bill_transfer_requests%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view')
    or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Transfer financial review permission denied';
 end if;
 select * into v_request from public.gs_table_bill_transfer_requests
  where id=p_request_id;
 if not found then raise exception 'Transfer request not found'; end if;
 return query
 select v_request.id,ri.order_item_id,o.id,ri.requested_quantity,
   oi.unit_price_iqd,
   (ri.requested_quantity::bigint*oi.unit_price_iqd)::bigint,
   coalesce(t.total,0)::bigint,coalesce(c.paid,0)::bigint,
   coalesce(e.verified,0)::bigint,coalesce(e.n,0)::bigint,
   coalesce(g.n,0)::bigint,coalesce(a.n,0)::bigint,
   false,
   case
    when v_request.status<>'pending' then 'request_not_pending'
    when o.table_visit_id is distinct from v_request.source_visit_id
      then 'source_visit_mismatch'
    when o.status='cancelled' then 'cancelled_order'
    when ri.requested_quantity>oi.quantity then 'quantity_changed'
    when coalesce(c.paid,0)>0 then 'cash_already_recorded'
    when coalesce(e.n,0)>0 then 'external_payment_evidence_requires_review'
    when coalesce(g.n,0)>0 then 'owner_offer_requires_review'
    when coalesce(a.n,0)>0 then 'overlapping_transfer_requests'
    else 'unified_settlement_not_yet_authoritative'
   end::text
 from public.gs_table_bill_transfer_request_items ri
 join public.gs_order_items oi on oi.id=ri.order_item_id
 join public.gs_orders o on o.id=oi.order_id
 left join lateral (select sum(i.line_total_iqd)::bigint total
   from public.gs_order_items i where i.order_id=o.id) t on true
 left join lateral (select sum(p.amount_iqd)::bigint paid
   from public.gs_cash_payments p where p.order_id=o.id) c on true
 left join lateral (select count(*)::bigint n,
   coalesce(sum(x.amount_iqd) filter(where x.verification_status='verified'),0)::bigint verified
   from public.gs_external_payment_evidence x where x.order_id=o.id) e on true
 left join lateral (select count(*)::bigint n
   from public.gs_owner_guest_offers x where x.order_id=o.id
    and x.status in ('pending','verified')) g on true
 left join lateral (select count(*)::bigint n
   from public.gs_table_bill_transfer_request_items x
   join public.gs_table_bill_transfer_requests r on r.id=x.transfer_request_id
   where x.order_item_id=oi.id and x.transfer_request_id<>v_request.id
    and r.status in ('pending','approved','applied')) a on true
 where ri.transfer_request_id=p_request_id
 order by ri.id;
end; $$;
revoke all on function public.gs_table_transfer_financial_preflight(bigint)
 from public,anon;
grant execute on function public.gs_table_transfer_financial_preflight(bigint)
 to authenticated;

-- This function is intentionally read-only and ready_to_apply is always
-- FALSE. It cannot establish the absence of external unrecorded payments.
