-- Upgrade 185: permission-controlled table creation with initial chair capacity.
create table if not exists public.gs_table_creation_events (
 id bigint generated always as identity primary key,
 table_id bigint not null references public.gs_cafe_tables(id) on delete restrict,
 table_number integer not null,
 initial_capacity integer not null check(initial_capacity between 1 and 50),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_table_creation_events enable row level security;
revoke all on public.gs_table_creation_events from public,anon,authenticated;
-- Audit rows cannot be updated or deleted by application roles.
create or replace function public.gs_create_cafe_table(
 p_table_number integer,p_capacity integer)
returns bigint language plpgsql volatile security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Not authorized to create tables';
 end if;
 if p_table_number is null or p_table_number <= 0 then
  raise exception 'Table number must be positive';
 end if;
 if p_capacity is null or p_capacity not between 1 and 50 then
  raise exception 'Chairs must be between 1 and 50';
 end if;
 insert into public.gs_cafe_tables(
  table_number,capacity,occupied,guests,tourism_mode,updated_by)
 values(p_table_number,p_capacity,false,0,false,auth.uid())
 returning id into v_id;
 insert into public.gs_table_creation_events(
  table_id,table_number,initial_capacity,created_by)
 values(v_id,p_table_number,p_capacity,auth.uid());
 return v_id;
end; $$;
revoke all on function public.gs_create_cafe_table(integer,integer) from public,anon;
grant execute on function public.gs_create_cafe_table(integer,integer) to authenticated;
