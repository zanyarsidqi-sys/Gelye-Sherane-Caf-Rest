-- Upgrade 570: read-only receipt-to-revision reconciliation. No mutations/retries.
create or replace function public.gs_table_replacement_reconciliation(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_receipt record; v_revision record; v_item record; v_dispatch integer; v_payments boolean;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order viewing permission required';
 end if;
 if p_request_id is null then raise exception 'Request identity required'; end if;
 select r.result,r.created_at into v_receipt from public.gs_table_replacement_requests r
 where r.request_id=p_request_id and r.actor_id=auth.uid();
 if not found then
  return jsonb_build_object('status','not_recorded','retry_safe',false);
 end if;
 select e.id,e.order_id,e.order_item_id,e.after_snapshot into v_revision
 from public.gs_order_revision_events e
 where e.id=(v_receipt.result->>'revision_id')::uuid;
 select i.id,i.order_id,i.product_id,i.unit_price_iqd,i.quantity into v_item
 from public.gs_order_items i where i.id=(v_receipt.result->>'order_item_id')::bigint;
 select count(*) into v_dispatch from public.gs_order_revision_dispatch d
 where d.revision_id=v_revision.id and d.destination_type='kitchen_revision';
 select exists(select 1 from public.gs_item_payment_allocations a where a.order_id=v_revision.order_id)
 or exists(select 1 from public.gs_cash_payments c where c.order_id=v_revision.order_id)
 or exists(select 1 from public.gs_unified_payment_ledger l where l.order_id=v_revision.order_id)
 into v_payments;
 return jsonb_build_object(
  'status','committed','retry_safe',false,'committed_at',v_receipt.created_at,
  'result',v_receipt.result,
  'revision_found',v_revision.id is not null,
  'revision_matches_receipt',coalesce(v_revision.order_item_id=(v_receipt.result->>'order_item_id')::bigint,false)
   and coalesce(v_revision.after_snapshot->>'product_id'=v_receipt.result->>'product_id',false),
  'kitchen_dispatch_recorded',v_dispatch>0,
  'current_item_matches_receipt',coalesce(v_item.product_id=(v_receipt.result->>'product_id')::bigint,false)
   and coalesce(v_item.unit_price_iqd=(v_receipt.result->>'unit_price_iqd')::bigint,false),
  'payment_records_present',coalesce(v_payments,false),
  'note','Payment presence is diagnostic only; this endpoint does not certify ledger accuracy or kitchen acknowledgment.');
end $$;
revoke all on function public.gs_table_replacement_reconciliation(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_reconciliation(uuid) to authenticated;
