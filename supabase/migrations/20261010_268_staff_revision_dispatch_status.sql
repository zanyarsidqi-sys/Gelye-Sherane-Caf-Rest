-- Upgrade 268: staff-only revision delivery/printing queue visibility.
-- Read-only diagnostics; does not claim to deliver notifications or print tickets.
create or replace function public.gs_staff_order_revision_dispatch(p_order_id bigint)
returns table(revision_id uuid, revision_number integer, change_type text,
 destination_type text, destination_key text, dispatch_status text,
 attempts integer, queued_at timestamptz, last_attempt_at timestamptz,
 acknowledged_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order view permission required';
 end if;
 if not exists (select 1 from public.gs_orders o
                where o.id=p_order_id) then
  raise exception 'Order not found';
 end if;
 return query
 select e.id, e.revision_number, e.change_type,
        d.destination_type,d.destination_key,d.status,d.attempts,
        d.created_at,d.last_attempt_at,d.acknowledged_at
 from public.gs_order_revision_events e
 join public.gs_order_revision_dispatch d on d.revision_id=e.id
 where e.order_id=p_order_id
 order by e.revision_number desc,d.created_at desc
 limit 250;
end $$;
revoke all on function public.gs_staff_order_revision_dispatch(bigint) from public,anon;
grant execute on function public.gs_staff_order_revision_dispatch(bigint) to authenticated;
