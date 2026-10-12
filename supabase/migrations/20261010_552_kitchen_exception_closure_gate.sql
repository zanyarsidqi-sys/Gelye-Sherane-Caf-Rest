-- Upgrade 552: only fully acknowledged and reconciled kitchen revisions can close an investigation.
-- Prevent premature closure while delivery is pending or failed. No financial mutations.
-- Upgrade 550: auditable exception resolution; never changes kitchen receipt or finances.
create or replace function public.gs_staff_close_kitchen_revision_exception(
 p_order_id bigint, p_case_id uuid, p_resolution_note text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_case public.gs_kitchen_revision_exception_cases%rowtype; v_state text;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_edit') and public.gs_can_access('kitchen','can_edit')) then
  raise exception 'Table order and kitchen editing permissions required';
 end if;
 if char_length(btrim(coalesce(p_resolution_note,''))) not between 10 and 1000 then
  raise exception 'Resolution note must contain 10 to 1000 characters';
 end if;
 select c.* into v_case from public.gs_kitchen_revision_exception_cases c
 join public.gs_order_revision_dispatch d on d.id=c.dispatch_id
 join public.gs_order_revision_events e on e.id=d.revision_id
 join public.gs_orders o on o.id=e.order_id
 where c.id=p_case_id and o.id=p_order_id and o.is_motel=false for update of c;
 if not found then raise exception 'Investigation case not found for this table order'; end if;
 if v_case.status='closed' then raise exception 'Case already closed'; end if;
 select r.reconciliation_state into v_state
 from public.gs_staff_kitchen_revision_reconciliation(p_order_id) r
 where r.dispatch_id=v_case.dispatch_id;
 if v_state is distinct from 'acknowledged_consistent' then
  raise exception 'Kitchen receipt must be consistently acknowledged before closing investigation';
 end if;
 update public.gs_kitchen_revision_exception_cases
 set status='closed', closed_by=auth.uid(), closed_at=now(), resolution_note=btrim(p_resolution_note)
 where id=p_case_id;
 return true;
end $$;
revoke all on function public.gs_staff_close_kitchen_revision_exception(bigint,uuid,text) from public,anon;
grant execute on function public.gs_staff_close_kitchen_revision_exception(bigint,uuid,text) to authenticated;
