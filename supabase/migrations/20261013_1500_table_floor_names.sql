-- Section 2: named floor assignment for each live café table.
alter table public.gs_cafe_tables
  add column if not exists floor_name text not null default 'Unassigned floor';

update public.gs_cafe_tables
set floor_name = 'Unassigned floor'
where floor_name is null or length(trim(floor_name)) = 0;

alter table public.gs_cafe_tables
  alter column floor_name set default 'Unassigned floor',
  alter column floor_name set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'gs_cafe_tables_floor_name_length'
      and conrelid = 'public.gs_cafe_tables'::regclass
  ) then
    alter table public.gs_cafe_tables
      add constraint gs_cafe_tables_floor_name_length
      check (length(trim(floor_name)) between 1 and 80);
  end if;
end;
$$;

create table if not exists public.gs_table_floor_events (
  id bigint generated always as identity primary key,
  table_id bigint not null references public.gs_cafe_tables(id) on delete restrict,
  table_number integer not null,
  old_floor_name text,
  new_floor_name text not null,
  changed_by uuid not null references auth.users(id),
  changed_at timestamptz not null default now(),
  constraint gs_table_floor_event_name_length
    check (length(trim(new_floor_name)) between 1 and 80)
);

create index if not exists gs_table_floor_events_history
  on public.gs_table_floor_events(table_id, changed_at desc);

alter table public.gs_table_floor_events enable row level security;
revoke all on public.gs_table_floor_events from public, anon, authenticated;

create or replace function public.gs_prevent_table_floor_event_changes()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'Table floor audit records cannot be changed';
end;
$$;

drop trigger if exists gs_table_floor_event_immutable
  on public.gs_table_floor_events;
create trigger gs_table_floor_event_immutable
  before update or delete on public.gs_table_floor_events
  for each row execute function public.gs_prevent_table_floor_event_changes();

-- Preserve the existing audited create-table RPC and make floor assignment atomic.
create or replace function public.gs_create_cafe_table_in_floor(
  p_table_number integer,
  p_capacity integer,
  p_floor_name text
)
returns bigint
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_id bigint;
  v_floor text := nullif(trim(coalesce(p_floor_name, '')), '');
begin
  if auth.uid() is null or not public.gs_can_access('tables', 'can_edit') then
    raise exception 'Not authorized to create tables';
  end if;
  if v_floor is null or length(v_floor) > 80 then
    raise exception 'Floor name must be between 1 and 80 characters';
  end if;

  v_id := public.gs_create_cafe_table(p_table_number, p_capacity);

  update public.gs_cafe_tables t
  set floor_name = v_floor, updated_at = now(), updated_by = auth.uid()
  where t.id = v_id;

  insert into public.gs_table_floor_events(
    table_id, table_number, old_floor_name, new_floor_name, changed_by
  )
  values(v_id, p_table_number, 'Unassigned floor', v_floor, auth.uid());

  return v_id;
end;
$$;

revoke all on function public.gs_create_cafe_table_in_floor(integer, integer, text)
  from public, anon;
grant execute on function public.gs_create_cafe_table_in_floor(integer, integer, text)
  to authenticated;

create or replace function public.gs_set_cafe_table_floor(
  p_table_number integer,
  p_floor_name text
)
returns table(table_number integer, floor_name text, event_id bigint)
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_table public.gs_cafe_tables%rowtype;
  v_floor text := nullif(trim(coalesce(p_floor_name, '')), '');
  v_event bigint;
begin
  if auth.uid() is null or not public.gs_can_access('tables', 'can_edit') then
    raise exception 'Not authorized to change table floor';
  end if;
  if v_floor is null or length(v_floor) > 80 then
    raise exception 'Floor name must be between 1 and 80 characters';
  end if;

  select t.* into v_table
  from public.gs_cafe_tables t
  where t.table_number = p_table_number
  for update;

  if not found then
    raise exception 'Table not found';
  end if;
  if v_table.occupied or coalesce(v_table.cleaning_needed, false) then
    raise exception 'Cannot change floor while the table is occupied or needs cleaning';
  end if;
  if v_table.floor_name = v_floor then
    return query select p_table_number, v_floor, null::bigint;
    return;
  end if;

  update public.gs_cafe_tables t
  set floor_name = v_floor, updated_at = now(), updated_by = auth.uid()
  where t.id = v_table.id;

  insert into public.gs_table_floor_events(
    table_id, table_number, old_floor_name, new_floor_name, changed_by
  )
  values(v_table.id, p_table_number, v_table.floor_name, v_floor, auth.uid())
  returning id into v_event;

  return query select p_table_number, v_floor, v_event;
end;
$$;

revoke all on function public.gs_set_cafe_table_floor(integer, text)
  from public, anon;
grant execute on function public.gs_set_cafe_table_floor(integer, text)
  to authenticated;

-- Reuse the same floor label in reservation choices without changing the
-- public RPC's result shape or changing how party size is validated.
create or replace function public.gs_public_reservable_table_options(
  p_party_size integer
)
returns table(table_id uuid, table_label text, seats integer)
language sql stable security definer set search_path = '' as $$
  select
    t.id,
    coalesce(c.floor_name, 'Unassigned floor') || ' · Table ' || t.table_label,
    t.seats
  from public.gs_reservable_tables t
  left join public.gs_cafe_tables c
    on c.table_number = case
      when t.table_label ~ '^[0-9]{1,10}$' then
        case
          when t.table_label::numeric between 1 and 2147483647
            then t.table_label::integer
          else null::integer
        end
      else null
    end
  where t.enabled and t.seats >= p_party_size and p_party_size between 1 and 30
  order by t.seats, coalesce(c.floor_name, 'Unassigned floor'), t.table_label
  limit 100;
$$;

revoke all on function public.gs_public_reservable_table_options(integer)
  from public;
grant execute on function public.gs_public_reservable_table_options(integer)
  to anon, authenticated;
