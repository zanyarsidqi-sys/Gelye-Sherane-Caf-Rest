-- Upgrade 572: join a committed replacement receipt to kitchen receipt audit evidence.
-- Read-only; do not infer that an acknowledgment means the food was prepared.
create or replace function public.gs_table_replacement_kitchen_receipt_status(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v jsonb; v_revision uuid; v_order bigint; v_count integer; v_consistent integer;
        v_problem integer; v_waiting integer; v_states jsonb;
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
 select count(*)::integer,
        count(*) filter(where k.reconciliation_state='acknowledged_consistent')::integer,
        count(*) filter(where k.reconciliation_state not in ('acknowledged_consistent','awaiting_kitchen_receipt'))::integer,
        count(*) filter(where k.reconciliation_state='awaiting_kitchen_receipt')::integer,
        coalesce(jsonb_agg(jsonb_build_object('dispatch_id',k.dispatch_id,'state',k.reconciliation_state,'acknowledged_at',k.dispatch_acknowledged_at)), '[]'::jsonb)
 into v_count,v_consistent,v_problem,v_waiting,v_states
 from public.gs_staff_kitchen_revision_reconciliation(v_order) k where k.revision_id=v_revision;
 return v || jsonb_build_object(
   'kitchen_receipt_state',case when v_count=0 then 'no_matching_dispatch'
     when v_problem>0 then 'receipt_investigation'
     when v_waiting>0 then 'awaiting_kitchen_receipt'
     when v_consistent=v_count then 'acknowledged_consistent'
     else 'receipt_investigation' end,
   'kitchen_acknowledged',v_count>0 and v_consistent=v_count,
   'kitchen_receipt_dispatches',v_states,
   'kitchen_receipt_note','Acknowledgment is a recorded kitchen receipt, not proof of preparation or financial settlement.');
end $$;
revoke all on function public.gs_table_replacement_kitchen_receipt_status(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_kitchen_receipt_status(uuid) to authenticated;
