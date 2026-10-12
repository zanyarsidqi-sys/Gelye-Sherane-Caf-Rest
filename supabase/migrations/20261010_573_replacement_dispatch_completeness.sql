-- Upgrade 573: evaluate every dispatch for the exact replacement revision.
-- The general kitchen board reconciliation is limited to 250 rows; it must not
-- be used as evidence that all dispatches for a receipt were inspected.
create or replace function public.gs_table_replacement_kitchen_receipt_status(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v jsonb; v_revision uuid; v_order bigint; v_count integer; v_consistent integer;
        v_problem integer; v_waiting integer; v_states jsonb; v_duplicate integer;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view')
      and public.gs_can_access('kitchen','can_view')) then
   raise exception 'Table order and kitchen viewing permissions required';
 end if;
 v := public.gs_table_replacement_reconciliation_guidance(p_request_id);
 if v->>'status' <> 'committed' then
   return v || jsonb_build_object('kitchen_receipt_state','unconfirmed','kitchen_acknowledged',null);
 end if;
 if nullif(v->'result'->>'revision_id','') is null then
   return v || jsonb_build_object('kitchen_receipt_state','missing_revision_identity','kitchen_acknowledged',false);
 end if;
 v_revision := (v->'result'->>'revision_id')::uuid;
 select e.order_id into v_order from public.gs_order_revision_events e where e.id=v_revision;
 if v_order is null then
   return v || jsonb_build_object('kitchen_receipt_state','missing_revision','kitchen_acknowledged',false);
 end if;
 -- Read all kitchen dispatches for the receipt's revision, not a limited board.
 with receipts as (
  select d.id, d.status, d.acknowledged_at, coalesce(a.audit_count,0) audit_count,
    case
      when coalesce(a.audit_count,0)>1 then 'duplicate_audit'
      when d.status='acknowledged' and coalesce(a.audit_count,0)=0 then 'missing_receipt_audit'
      when d.status<>'acknowledged' and coalesce(a.audit_count,0)>0 then 'audit_without_acknowledged_status'
      when d.status='acknowledged' and d.acknowledged_at is null then 'missing_dispatch_timestamp'
      when d.status='acknowledged' and a.audit_acknowledged_at is distinct from d.acknowledged_at then 'timestamp_mismatch'
      when d.status='acknowledged' then 'acknowledged_consistent'
      when d.status='failed' then 'failed_requires_recovery'
      else 'awaiting_kitchen_receipt' end as state
  from public.gs_order_revision_dispatch d
  left join lateral (
   select count(*)::integer audit_count, min(x.acknowledged_at) audit_acknowledged_at
   from public.gs_kitchen_revision_acknowledgement_audit x where x.dispatch_id=d.id
  ) a on true
  where d.revision_id=v_revision and d.destination_type='kitchen_revision'
 )
 select count(*)::integer,
   count(*) filter(where state='acknowledged_consistent')::integer,
   count(*) filter(where state not in ('acknowledged_consistent','awaiting_kitchen_receipt'))::integer,
   count(*) filter(where state='awaiting_kitchen_receipt')::integer,
   count(*) filter(where state='duplicate_audit')::integer,
   coalesce(jsonb_agg(jsonb_build_object('dispatch_id',id,'state',state,'acknowledged_at',acknowledged_at,'audit_count',audit_count) order by id) filter(where id is not null),'[]'::jsonb)
 into v_count,v_consistent,v_problem,v_waiting,v_duplicate,v_states
 from receipts;
 return v || jsonb_build_object(
   'kitchen_receipt_state',case when v_count=0 then 'no_matching_dispatch'
     when v_problem>0 then 'receipt_investigation'
     when v_waiting>0 then 'awaiting_kitchen_receipt'
     when v_consistent=v_count then 'acknowledged_consistent'
     else 'receipt_investigation' end,
   'kitchen_acknowledged',v_count>0 and v_consistent=v_count,
   'kitchen_receipt_dispatch_count',v_count,
   'kitchen_receipt_consistent_count',v_consistent,
   'kitchen_receipt_problem_count',v_problem,
   'kitchen_receipt_waiting_count',v_waiting,
   'kitchen_receipt_duplicate_audit_count',v_duplicate,
   'kitchen_receipt_dispatches',v_states,
   'kitchen_receipt_guidance',case when v_count=0 then 'No dispatch found: investigate the revision before further action.'
     when v_problem>0 then 'One or more dispatches have inconsistent evidence. Review each dispatch and its audit; do not resend automatically.'
     when v_waiting>0 then 'Kitchen acknowledgment is pending for one or more dispatches. Confirm with kitchen staff; do not resend automatically.'
     else 'All recorded kitchen dispatch receipts agree. This does not prove preparation or payment settlement.' end,
   'kitchen_receipt_note','Acknowledgment is a recorded kitchen receipt, not proof of preparation or financial settlement.');
end $$;
revoke all on function public.gs_table_replacement_kitchen_receipt_status(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_kitchen_receipt_status(uuid) to authenticated;
