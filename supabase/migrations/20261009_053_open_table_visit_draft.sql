-- Upgrade 52 DRAFT: authorized atomic opening of a cafe table visit.
-- DO NOT DEPLOY independently. Legacy occupancy RPC and reservation checks
-- must be reconciled first; see DASHBOARD_UPGRADE_52.md.
create or replace function public.gs_open_cafe_table_visit(
 p_table_number integer, p_guests integer, p_tourism boolean default false)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype; v_visit_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Not authorized to open table visits';
 end if;
 if p_tourism is null then raise exception 'Tourism mode is required'; end if;
 select * into v_table from public.gs_cafe_tables
 where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 if p_guests is null or p_guests < 1 or p_guests > v_table.capacity then
   raise exception 'Guest count exceeds table capacity'; end if;
 if v_table.occupied or coalesce(v_table.cleaning_needed,false) then
   raise exception 'Table is occupied or requires cleaning'; end if;
 if exists (select 1 from public.gs_table_visits v
   where v.table_id=v_table.id and v.status <> 'closed') then
   raise exception 'Table has an open visit'; end if;
 -- TODO: reservation hold / seating authorization check must be added here.
 insert into public.gs_table_visits(table_id,opened_by,guest_count,tourism_mode)
 values(v_table.id,auth.uid(),p_guests,p_tourism) returning id into v_visit_id;
 update public.gs_cafe_tables set occupied=true,guests=p_guests,
  tourism_mode=p_tourism,updated_at=now(),updated_by=auth.uid()
 where id=v_table.id;
 return v_visit_id;
end; $$;
revoke all on function public.gs_open_cafe_table_visit(integer,integer,boolean)
 from public,anon;
grant execute on function public.gs_open_cafe_table_visit(integer,integer,boolean)
 to authenticated;

-- Prevent legacy table-state RPC from opening an occupied table without a
-- visit. CAUTION: this also disables legacy guest/mode edits and releases.
-- Replace these flows with audited visit-aware RPCs before deployment.
revoke execute on function public.gs_update_cafe_table(integer,boolean,integer,boolean)
 from authenticated;

-- This upgrade does NOT backfill old visits, close visits, or implement
-- reservation locking, table transfers, release, or complete audit logging.
