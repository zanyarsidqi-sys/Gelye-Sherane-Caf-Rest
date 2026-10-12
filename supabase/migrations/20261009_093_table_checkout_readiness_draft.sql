-- Upgrade 93: fail-closed physical table checkout readiness inspection.
-- No state changes. A provisional financial balance cannot authorize release.
create or replace function public.gs_table_checkout_readiness(p_table_id bigint)
returns table(table_id bigint, active_visit_id bigint, occupied boolean,
 guests_departed boolean, cleaning_needed boolean,
 pending_cleaning_tasks bigint, pending_shisha_tasks bigint,
 unresolved_guest_moves bigint, checkout_authorized boolean, blocking_reason text)
language plpgsql stable security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype; v_visit_id bigint;
 v_clean bigint;v_shisha bigint;v_moves bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view')
  or not (public.gs_can_access('invoices_payments','can_view')
   or public.gs_can_access('payments_management','can_view')) then
  raise exception 'Checkout readiness inspection denied';
 end if;
 select * into v_table from public.gs_cafe_tables where id=p_table_id;
 if not found then raise exception 'Table not found'; end if;
 select v.id into v_visit_id from public.gs_table_visits v
 where v.table_id=p_table_id and v.status='active' order by v.id desc limit 1;
 select count(*) into v_clean from public.gs_table_service_tasks s
 where s.table_id=p_table_id and s.request_type='table_cleaning'
 and s.status not in ('completed','cancelled');
 select count(*) into v_shisha from public.gs_table_service_tasks s
 where s.table_id=p_table_id and s.request_type='shisha_pickup'
 and s.status not in ('completed','cancelled');
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
 when v_table.guests_departed_at is null then 'BLOCKED: guest departure not confirmed'
 when v_clean>0 or v_shisha>0 then 'BLOCKED: outstanding cleaning or shisha tasks'
 when v_table.cleaning_needed then 'BLOCKED: cleaning state not released'
 else 'BLOCKED: authoritative financial settlement and final release not implemented'
 end::text;
end; $$;
revoke all on function public.gs_table_checkout_readiness(bigint) from public,anon;
grant execute on function public.gs_table_checkout_readiness(bigint) to authenticated;
-- This function always returns checkout_authorized=false. It is not a release RPC.
