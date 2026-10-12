-- Upgrade 94: visit-scoped checkout readiness and legacy-task ambiguity guard.
-- Read-only, fail closed. Never closes or releases a table.
create or replace function public.gs_table_checkout_readiness(p_table_id bigint)
returns table(table_id bigint, active_visit_id bigint, occupied boolean,
 guests_departed boolean, cleaning_needed boolean,
 pending_cleaning_tasks bigint, pending_shisha_tasks bigint,
 unresolved_guest_moves bigint, checkout_authorized boolean, blocking_reason text)
language plpgsql stable security definer set search_path='' as $$
declare
 v_table public.gs_cafe_tables%rowtype;
 v_visit_id bigint;
 v_clean bigint := 0;
 v_shisha bigint := 0;
 v_moves bigint := 0;
 v_unlinked bigint := 0;
 v_historical bigint := 0;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view')
  or not (public.gs_can_access('invoices_payments','can_view')
   or public.gs_can_access('payments_management','can_view')) then
  raise exception 'Checkout readiness inspection denied';
 end if;
 select * into v_table from public.gs_cafe_tables where id=p_table_id;
 if not found then raise exception 'Table not found'; end if;
 select v.id into v_visit_id from public.gs_table_visits v
  where v.table_id=p_table_id and v.status='active'
  order by v.id desc limit 1;
 -- Do not mix tasks belonging to an older visit with the current visit.
 select count(*) filter (where s.request_type='table_cleaning'),
        count(*) filter (where s.request_type='shisha_pickup')
 into v_clean,v_shisha
 from public.gs_table_service_tasks s
 where s.table_visit_id=v_visit_id
   and s.status not in ('completed','cancelled');
 -- Unlinked outstanding tasks are ambiguous and must block release.
 select count(*) into v_unlinked from public.gs_table_service_tasks s
 where s.table_id=p_table_id and s.table_visit_id is null
  and s.status not in ('completed','cancelled');
 -- Old unlinked orders must never be silently attached to the new visit.
 select count(*) into v_historical from public.gs_orders o
 where o.is_motel=false and o.table_visit_id is null
  and o.destination=v_table.table_number::text and o.status<>'cancelled';
 select count(*) into v_moves from public.gs_table_guest_move_requests m
 where m.status='pending' and v_visit_id is not null
  and (m.source_visit_id=v_visit_id or m.destination_visit_id=v_visit_id);
 return query select v_table.id,v_visit_id,v_table.occupied,
  (v_table.guests_departed_at is not null),v_table.cleaning_needed,
  v_clean,v_shisha,v_moves,false,
  case
   when v_visit_id is null then 'BLOCKED: no active visit; legacy state must be reconciled'
   when not v_table.occupied then 'BLOCKED: table is not an occupied checkout candidate'
   when v_moves>0 then 'BLOCKED: pending guest movement request'
   when v_unlinked>0 then 'BLOCKED: unlinked outstanding service tasks require review'
   when v_historical>0 then 'BLOCKED: unlinked historical orders require review'
   when v_table.guests_departed_at is null then 'BLOCKED: guest departure not confirmed'
   when v_clean>0 or v_shisha>0 then 'BLOCKED: outstanding visit-specific cleaning or shisha tasks'
   when v_table.cleaning_needed then 'BLOCKED: cleaning state not released'
   else 'BLOCKED: authoritative financial settlement and final release not implemented'
  end::text;
end; $$;
revoke all on function public.gs_table_checkout_readiness(bigint) from public,anon;
grant execute on function public.gs_table_checkout_readiness(bigint) to authenticated;
-- checkout_authorized ALWAYS false; no payment or release side effects.
