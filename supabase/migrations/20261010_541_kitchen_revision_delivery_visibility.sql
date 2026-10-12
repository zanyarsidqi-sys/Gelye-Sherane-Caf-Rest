-- Upgrade 541: read-only delivery and human acknowledgment evidence for replacement revisions.
-- Acknowledgment is NOT evidence of physical printing or delivery by a worker.
drop function if exists public.gs_staff_order_revision_dispatch(bigint);
create function public.gs_staff_order_revision_dispatch(p_order_id bigint)
returns table(dispatch_id uuid, revision_id uuid, revision_number integer, change_type text,
 destination_type text, destination_key text, dispatch_status text,
 attempts integer, queued_at timestamptz, last_attempt_at timestamptz,
 acknowledged_at timestamptz, acknowledged_by uuid, retry_count bigint,
 last_retry_at timestamptz, last_retry_reason text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order view permission required'; end if;
 if not exists(select 1 from public.gs_orders o where o.id=p_order_id) then
  raise exception 'Order not found'; end if;
 return query
 select d.id,e.id,e.revision_number,e.change_type,d.destination_type,
 d.destination_key,d.status,d.attempts,d.created_at,d.last_attempt_at,
 d.acknowledged_at,a.acknowledged_by,
 coalesce(r.retry_count,0),r.last_retry_at,r.last_retry_reason
 from public.gs_order_revision_events e
 join public.gs_order_revision_dispatch d on d.revision_id=e.id
 left join public.gs_kitchen_revision_acknowledgement_audit a on a.dispatch_id=d.id
 left join lateral (
  select count(*)::bigint as retry_count,max(x.retried_at) as last_retry_at,
   (array_agg(x.reason order by x.retried_at desc,x.id desc))[1] as last_retry_reason
  from public.gs_kitchen_revision_retry_audit x where x.dispatch_id=d.id
 ) r on true
 where e.order_id=p_order_id
 order by e.revision_number desc,d.created_at desc limit 250;
end $$;
revoke all on function public.gs_staff_order_revision_dispatch(bigint) from public,anon;
grant execute on function public.gs_staff_order_revision_dispatch(bigint) to authenticated;
