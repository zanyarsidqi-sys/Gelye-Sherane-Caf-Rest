-- Upgrade 1211: staff-only handoff history and cross-section consistency diagnostics.
-- No financial, invoice, waste or delivery records are modified by these read-only RPCs.
create or replace function public.gs_table_replacement_handoff_history(p_order_id bigint default null)
returns table(event_id bigint, revision_id bigint, order_id bigint, event_kind text,
 event_at timestamptz, actor_name text, assigned_employee_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is not null and p_order_id <= 0 then raise exception 'Invalid order identifier'; end if;
 return query
 select e.id,e.revision_id,r.order_id,e.event_kind,e.event_at,
   coalesce(nullif(actor.full_name,''),'Employee')::text,
   case when e.assigned_to is null then null
     else coalesce(nullif(recipient.full_name,''),'Assigned employee') end::text
 from public.gs_cafe_replacement_delivery_events e
 join public.gs_cafe_correction_station_revisions r on r.id=e.revision_id
 left join public.employee_profiles actor on actor.user_id=e.actor_id
 left join public.employee_profiles recipient on recipient.user_id=e.assigned_to
 where r.revision_kind='prepare_replacement'
   and (p_order_id is null or r.order_id=p_order_id)
 order by e.event_at desc,e.id desc limit 200;
end; $$;
revoke all on function public.gs_table_replacement_handoff_history(bigint) from public,anon;
grant execute on function public.gs_table_replacement_handoff_history(bigint) to authenticated;

-- Read-only diagnostics: identify impossible/missing handoff states without mutating billing.
create or replace function public.gs_replacement_handoff_consistency(p_order_id bigint default null)
returns table(revision_id bigint,order_id bigint,issue_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is not null and p_order_id <= 0 then raise exception 'Invalid order identifier'; end if;
 return query
 select r.id,r.order_id,
 case
  when r.preparation_state='ready' and d.revision_id is null then 'READY_WITHOUT_DELIVERY_TASK'
  when d.delivered_at is not null and d.picked_up_at is null then 'DELIVERED_WITHOUT_PICKUP'
  when d.picked_up_at is not null and d.accepted_at is null then 'PICKED_UP_WITHOUT_ACCEPTANCE'
  when d.accepted_at is not null and d.assigned_to is null then 'ACCEPTED_WITHOUT_ASSIGNEE'
  when d.assigned_to is not null and d.assigned_at is null then 'ASSIGNED_WITHOUT_TIMESTAMP'
  else 'OK' end::text
 from public.gs_cafe_correction_station_revisions r
 left join public.gs_cafe_replacement_delivery_tasks d on d.revision_id=r.id
 where r.revision_kind='prepare_replacement'
 and (p_order_id is null or r.order_id=p_order_id)
 and ((r.preparation_state='ready' and d.revision_id is null)
  or (d.delivered_at is not null and d.picked_up_at is null)
  or (d.picked_up_at is not null and d.accepted_at is null)
  or (d.accepted_at is not null and d.assigned_to is null)
  or (d.assigned_to is not null and d.assigned_at is null))
 order by r.id desc limit 100;
end; $$;
revoke all on function public.gs_replacement_handoff_consistency(bigint) from public,anon;
grant execute on function public.gs_replacement_handoff_consistency(bigint) to authenticated;
