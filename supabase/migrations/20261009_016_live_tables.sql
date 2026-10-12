-- Run after 20261009_001_phase3_order_foundation.sql.
create table if not exists public.gs_cafe_tables (
 id bigint generated always as identity primary key,
 table_number integer not null unique check(table_number > 0),
 capacity integer not null default 4 check(capacity between 1 and 50),
 occupied boolean not null default false,
 guests integer not null default 0 check(guests between 0 and 50),
 tourism_mode boolean not null default false,
 updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 constraint gs_table_empty_reset check (occupied or (guests = 0 and tourism_mode = false)),
 constraint gs_table_guests check (not occupied or guests > 0)
);
alter table public.gs_cafe_tables enable row level security;
create policy gs_cafe_tables_read on public.gs_cafe_tables for select to authenticated
 using (public.gs_can_access('tables','can_view'));
-- Seed is deliberately not automatic: real table count must be configured by management.
create or replace function public.gs_update_cafe_table(p_table_number integer, p_occupied boolean, p_guests integer, p_tourism boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_capacity integer;
begin
 if not public.gs_can_access('tables','can_edit') then raise exception 'Permission denied'; end if;
 select capacity into v_capacity from public.gs_cafe_tables where table_number=p_table_number for update;
 if not found then raise exception 'Table not configured'; end if;
 if coalesce(p_occupied,false) and (p_guests is null or p_guests < 1 or p_guests > v_capacity) then
   raise exception 'Invalid guest count for table capacity';
 end if;
 update public.gs_cafe_tables set occupied=coalesce(p_occupied,false),
 guests=case when coalesce(p_occupied,false) then p_guests else 0 end,
 tourism_mode=case when coalesce(p_occupied,false) then coalesce(p_tourism,false) else false end,
 updated_at=now(), updated_by=auth.uid() where table_number=p_table_number;
end;$$;
revoke all on function public.gs_update_cafe_table(integer,boolean,integer,boolean) from public;
grant execute on function public.gs_update_cafe_table(integer,boolean,integer,boolean) to authenticated;
