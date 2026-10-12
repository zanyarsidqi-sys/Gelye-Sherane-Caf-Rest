-- Upgrade 546: read-only, permission-scoped kitchen receipt reconciliation.
-- Do not automatically repair mismatches or equate receipt with printing.
create or replace function public.gs_staff_kitchen_revision_reconciliation(p_order_id bigint)
returns table(dispatch_id uuid, revision_id uuid, revision_number integer,
 dispatch_status text, audit_count bigint, audit_employee uuid,
 dispatch_acknowledged_at timestamptz, audit_acknowledged_at timestamptz,
 reconciliation_state text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view')
     and public.gs_can_access('kitchen','can_view')) then
  raise exception 'Table orders and kitchen view permissions required';
 end if;
 if p_order_id is null or not exists(select 1 from public.gs_orders o where o.id=p_order_id and o.is_motel=false) then
  raise exception 'Table order not found';
 end if;
 return query
 select d.id,e.id,e.revision_number,d.status,
        coalesce(a.audit_count,0),a.acknowledged_by,d.acknowledged_at,a.acknowledged_at,
        case
         when coalesce(a.audit_count,0)>1 then 'duplicate_audit'
         when d.status='acknowledged' and coalesce(a.audit_count,0)=0 then 'missing_receipt_audit'
         when d.status<>'acknowledged' and coalesce(a.audit_count,0)>0 then 'audit_without_acknowledged_status'
         when d.status='acknowledged' and d.acknowledged_at is null then 'missing_dispatch_timestamp'
         when d.status='acknowledged' and a.acknowledged_at is distinct from d.acknowledged_at then 'timestamp_mismatch'
         when d.status='acknowledged' then 'acknowledged_consistent'
         when d.status='failed' then 'failed_requires_recovery'
         else 'awaiting_kitchen_receipt'
        end
 from public.gs_order_revision_events e
 join public.gs_order_revision_dispatch d on d.revision_id=e.id
 left join lateral (
   select count(*)::bigint audit_count,
          (array_agg(x.acknowledged_by order by x.acknowledged_at))[1] acknowledged_by,
          (array_agg(x.acknowledged_at order by x.acknowledged_at))[1] acknowledged_at
   from public.gs_kitchen_revision_acknowledgement_audit x where x.dispatch_id=d.id
 ) a on true
 where e.order_id=p_order_id and d.destination_type='kitchen_revision'
   and e.change_type='price_adjustment'
   and e.before_snapshot ? 'product_id' and e.after_snapshot ? 'product_id'
   and e.before_snapshot->>'product_id' is distinct from e.after_snapshot->>'product_id'
 order by e.revision_number desc,d.created_at desc limit 250;
end $$;
revoke all on function public.gs_staff_kitchen_revision_reconciliation(bigint) from public,anon;
grant execute on function public.gs_staff_kitchen_revision_reconciliation(bigint) to authenticated;
