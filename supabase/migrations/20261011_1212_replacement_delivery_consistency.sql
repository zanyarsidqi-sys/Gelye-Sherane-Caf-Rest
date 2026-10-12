-- Upgrade 1212: deeper, read-only handoff validation for Table Orders.
-- Keep the existing RPC signature to avoid breaking older Flutter clients.
-- No writes to orders, corrections, payments or deliveries.
create or replace function public.gs_replacement_handoff_consistency(p_order_id bigint default null)
returns table(revision_id bigint,order_id bigint,issue_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Table Orders view permission required';
 end if;
 if p_order_id is not null and p_order_id <= 0 then
   raise exception 'Invalid order identifier';
 end if;
 return query
 select r.id, r.order_id, flags.code
 from public.gs_cafe_correction_station_revisions r
 left join public.gs_cafe_replacement_delivery_tasks d on d.revision_id=r.id
 cross join lateral (values
   ('READY_WITHOUT_DELIVERY_TASK', r.preparation_state='ready' and d.revision_id is null),
   ('TASK_BEFORE_READY', d.revision_id is not null and r.preparation_state<>'ready'),
   ('READY_WITHOUT_TIMESTAMP', r.preparation_state='ready' and r.preparation_ready_at is null),
   ('DELIVERED_WITHOUT_PICKUP', d.delivered_at is not null and d.picked_up_at is null),
   ('PICKED_UP_WITHOUT_ACCEPTANCE', d.picked_up_at is not null and d.accepted_at is null),
   ('ACCEPTED_WITHOUT_ASSIGNEE', d.accepted_at is not null and d.assigned_to is null),
   ('ASSIGNED_WITHOUT_TIMESTAMP', d.assigned_to is not null and d.assigned_at is null),
   ('UNASSIGNED_WITH_ACCEPTANCE', d.assigned_to is null and d.accepted_at is not null),
   ('ACCEPTED_BEFORE_ASSIGNMENT', d.accepted_at is not null and d.assigned_at is not null and d.accepted_at<d.assigned_at),
   ('PICKUP_BEFORE_ACCEPTANCE', d.picked_up_at is not null and d.accepted_at is not null and d.picked_up_at<d.accepted_at),
   ('DELIVERY_BEFORE_PICKUP', d.delivered_at is not null and d.picked_up_at is not null and d.delivered_at<d.picked_up_at),
   ('TASK_CREATED_BEFORE_READY', d.created_at is not null and r.preparation_ready_at is not null and d.created_at<r.preparation_ready_at),
   ('DELIVERY_WITHOUT_EVENT', d.delivered_at is not null and not exists (
     select 1 from public.gs_cafe_replacement_delivery_events e
     where e.revision_id=r.id and e.event_kind='delivered')),
   ('PICKUP_WITHOUT_EVENT', d.picked_up_at is not null and not exists (
     select 1 from public.gs_cafe_replacement_delivery_events e
     where e.revision_id=r.id and e.event_kind='picked_up'))
 ) as flags(code,invalid)
 where r.revision_kind='prepare_replacement'
   and (p_order_id is null or r.order_id=p_order_id)
   and flags.invalid is true
 order by r.id desc,flags.code limit 200;
end; $$;
revoke all on function public.gs_replacement_handoff_consistency(bigint) from public,anon;
grant execute on function public.gs_replacement_handoff_consistency(bigint) to authenticated;
