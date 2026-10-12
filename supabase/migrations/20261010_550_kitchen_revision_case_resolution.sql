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
 if v_state is distinct from 'acknowledged_consistent' and
    v_state is distinct from 'awaiting_kitchen_receipt' and
    v_state is distinct from 'failed_requires_recovery' then
  raise exception 'Receipt audit inconsistency persists; resolve underlying issue before closure';
 end if;
 update public.gs_kitchen_revision_exception_cases
 set status='closed', closed_by=auth.uid(), closed_at=now(), resolution_note=btrim(p_resolution_note)
 where id=p_case_id;
 return true;
end $$;
revoke all on function public.gs_staff_close_kitchen_revision_exception(bigint,uuid,text) from public,anon;
grant execute on function public.gs_staff_close_kitchen_revision_exception(bigint,uuid,text) to authenticated;

-- Add resolution metadata to existing protected history RPC.
drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint);
create function public.gs_staff_kitchen_revision_exception_cases(p_order_id bigint)
returns table(case_id uuid,dispatch_id uuid,reconciliation_state text,investigation_note text,opened_by uuid,opened_at timestamptz,status text,closed_by uuid,closed_at timestamptz,resolution_note text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view') and public.gs_can_access('kitchen','can_view')) then
  raise exception 'Table orders and kitchen view permissions required';
 end if;
 return query select c.id,c.dispatch_id,c.reconciliation_state,c.investigation_note,c.opened_by,c.opened_at,c.status,c.closed_by,c.closed_at,c.resolution_note
 from public.gs_kitchen_revision_exception_cases c
 join public.gs_order_revision_dispatch d on d.id=c.dispatch_id
 join public.gs_order_revision_events e on e.id=d.revision_id
 join public.gs_orders o on o.id=e.order_id
 where o.id=p_order_id and o.is_motel=false order by c.opened_at desc limit 250;
end $$;
revoke all on function public.gs_staff_kitchen_revision_exception_cases(bigint) from public,anon;
grant execute on function public.gs_staff_kitchen_revision_exception_cases(bigint) to authenticated;
