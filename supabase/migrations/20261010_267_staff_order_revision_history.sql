-- Read-only audited order revision history for authorized staff.
create or replace function public.gs_staff_table_order_revisions(p_order_id bigint)
returns table(revision_number integer, change_type text, order_item_id bigint,
 before_snapshot jsonb, after_snapshot jsonb, changed_by uuid,
 changed_at timestamptz, reason text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('tables','can_view')) then
  raise exception 'Not authorized to view order revisions';
 end if;
 if not exists (select 1 from public.gs_orders o
  join public.gs_table_visits v on v.id=o.table_visit_id
  where o.id=p_order_id and o.is_motel=false and v.status='open') then
  raise exception 'Order not found in an open table visit';
 end if;
 return query select e.revision_number,e.change_type,e.order_item_id,
  e.before_snapshot,e.after_snapshot,e.changed_by,e.changed_at,e.reason
 from public.gs_order_revision_events e where e.order_id=p_order_id
 order by e.revision_number desc,e.changed_at desc,e.id desc limit 250;
end $$;
revoke all on function public.gs_staff_table_order_revisions(bigint) from public,anon;
grant execute on function public.gs_staff_table_order_revisions(bigint) to authenticated;
