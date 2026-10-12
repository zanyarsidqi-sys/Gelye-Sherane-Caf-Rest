-- DRAFT: deploy only after reviewing role permissions, audit coverage and table release guards.
-- Table-service requests are separate from chargeable orders.
create table if not exists public.gs_table_service_tasks (
 id bigint generated always as identity primary key,
 table_id bigint not null references public.gs_cafe_tables(id),
 request_type text not null check (request_type in (
  'extra_tissues','fork','spoon','knife','extra_plate','extra_glass',
  'extra_chair','water_request','condiments','call_waiter','dish_pickup',
  'shisha_pickup','shisha_service','table_cleaning','other')),
 quantity integer not null default 1 check (quantity between 1 and 50),
 priority text not null default 'normal' check (priority in ('normal','urgent')),
 notes text check (char_length(notes) <= 1000),
 status text not null default 'pending'
   check (status in ('pending','assigned','accepted','in_progress','completed','cancelled')),
 assigned_employee_id uuid references auth.users(id),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 completed_at timestamptz
);
create index if not exists gs_table_service_tasks_table_idx
 on public.gs_table_service_tasks(table_id, created_at desc);
create index if not exists gs_table_service_tasks_assignee_idx
 on public.gs_table_service_tasks(assigned_employee_id, status);
alter table public.gs_table_service_tasks enable row level security;
revoke all on public.gs_table_service_tasks from anon, authenticated;

create or replace function public.gs_dashboard_table_service_tasks(p_table_id text default null)
returns table (
 id bigint, table_id bigint, table_label text, request_type text,
 quantity integer, priority text, notes text, status text,
 assigned_employee_name text, created_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
declare v_table_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view')
    or not public.gs_can_access('tables','can_view') then
   raise exception 'Table service access denied';
 end if;
 if p_table_id is not null then
   if p_table_id !~ '^[0-9]{1,18}$' then
     raise exception 'Invalid table identifier';
   end if;
   v_table_id := p_table_id::bigint;
 end if;
 return query
 select t.id, t.table_id, ct.table_number::text, t.request_type,
        t.quantity, t.priority, t.notes, t.status,
        case when t.assigned_employee_id is null then null
             else 'Assigned employee ' || left(t.assigned_employee_id::text,8) end,
        t.created_at
 from public.gs_table_service_tasks t
 join public.gs_cafe_tables ct on ct.id=t.table_id
 where v_table_id is null or t.table_id=v_table_id
 order by case when t.priority='urgent' then 0 else 1 end, t.created_at desc
 limit 300;
end; $$;
revoke all on function public.gs_dashboard_table_service_tasks(text) from public, anon;
grant execute on function public.gs_dashboard_table_service_tasks(text) to authenticated;

-- Intentionally no client write grants or write RPCs yet.
-- Cashier assignment, employee notifications, transition validation,
-- automatic checkout cleaning, shisha detection, and audit writers are pending.
