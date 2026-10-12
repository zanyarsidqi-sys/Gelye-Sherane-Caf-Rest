-- Upgrade 125: prevent newly created legacy unlinked table orders from
-- bypassing the visit-specific cash-only checkout checks.
-- Existing historical unlinked orders are not modified or guessed into visits.
create or replace function public.gs_block_new_unlinked_table_orders()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_table_id bigint;v_visit_id bigint;
begin
  if new.is_motel is distinct from false or new.table_visit_id is not null
     or new.destination is null then return new; end if;
  -- Only match canonical numeric table numbers; never infer a visit from
  -- an arbitrary text destination (e.g. delivery notes).
  if new.destination !~ '^[0-9]{1,8}$' then return new; end if;
  select id into v_table_id from public.gs_cafe_tables
    where table_number::text=new.destination limit 1;
  if v_table_id is null then return new; end if;
  -- Checkout locks this table row first. A concurrent legacy order writer
  -- waits and then sees the final state, rather than slipping past checkout.
  perform 1 from public.gs_cafe_tables where id=v_table_id for update;
  select id into v_visit_id from public.gs_table_visits
    where table_id=v_table_id and status<>'closed' limit 1;
  if v_visit_id is not null then
    raise exception 'Table order must be linked to active visit %',v_visit_id;
  end if;
  -- A table order without an active visit is not a valid new sale either.
  raise exception 'Cannot create unlinked table order without active visit';
end; $$;
revoke all on function public.gs_block_new_unlinked_table_orders()
 from public,anon,authenticated;
drop trigger if exists gs_block_new_unlinked_table_orders on public.gs_orders;
create trigger gs_block_new_unlinked_table_orders
 before insert or update of destination,is_motel,table_visit_id
 on public.gs_orders for each row
 when (new.table_visit_id is null)
 execute function public.gs_block_new_unlinked_table_orders();
