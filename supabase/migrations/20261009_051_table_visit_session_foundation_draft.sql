-- Dashboard Upgrade 50: DRAFT visit/session identity foundation.
-- Additive only: DOES NOT automatically link historical orders by table number.
-- Migration must be reviewed against the deployed schema before execution.
create table if not exists public.gs_table_visits (
 id bigint generated always as identity primary key,
 table_id bigint not null references public.gs_cafe_tables(id),
 opened_at timestamptz not null default now(),
 opened_by uuid not null references auth.users(id),
 closed_at timestamptz,
 closed_by uuid references auth.users(id),
 status text not null default 'active' check (status in ('active','cleaning','closed')),
 guest_count integer not null check (guest_count between 1 and 50),
 tourism_mode boolean not null default false,
 constraint gs_visit_closed_consistency check
  ((status='closed' and closed_at is not null and closed_by is not null)
   or (status<>'closed' and closed_at is null and closed_by is null))
);
create unique index if not exists gs_table_visits_one_open_per_table
 on public.gs_table_visits(table_id) where status<>'closed';
create index if not exists gs_table_visits_table_history
 on public.gs_table_visits(table_id,opened_at desc);
alter table public.gs_table_visits enable row level security;
revoke all on public.gs_table_visits from anon,authenticated;

-- Nullable foreign keys avoid falsely assigning existing data to the latest guest.
alter table public.gs_orders add column if not exists table_visit_id bigint
 references public.gs_table_visits(id);
alter table public.gs_table_service_tasks add column if not exists table_visit_id bigint
 references public.gs_table_visits(id);
alter table public.gs_owner_guest_offers add column if not exists table_visit_id bigint
 references public.gs_table_visits(id);
create index if not exists gs_orders_table_visit_idx on public.gs_orders(table_visit_id);
create index if not exists gs_service_tasks_table_visit_idx on public.gs_table_service_tasks(table_visit_id);

create or replace function public.gs_dashboard_active_table_visits()
returns table(visit_id bigint,table_id bigint,table_number integer,
 guest_count integer,tourism_mode boolean,status text,opened_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view')
    or not public.gs_can_access('tables','can_view') then
  raise exception 'Visit access denied';
 end if;
 return query
 select v.id,v.table_id,t.table_number,v.guest_count,v.tourism_mode,
        v.status,v.opened_at
 from public.gs_table_visits v join public.gs_cafe_tables t on t.id=v.table_id
 where v.status<>'closed' order by v.opened_at desc limit 200;
end; $$;
revoke all on function public.gs_dashboard_active_table_visits() from public,anon;
grant execute on function public.gs_dashboard_active_table_visits() to authenticated;

-- Do not expose a visit-creation RPC until the table occupancy update, order
-- creation and payment flows can atomically bind a visit. Otherwise a visit
-- could be opened for an already occupied table or outlive its reservation.
-- Future requirements: bind order at creation under table lock, prevent
-- changing visit ID after payment, link service tasks and owner offers, enforce
-- settlement across cash/credit/card/online and owner complimentary ledger,
-- close visit only after cleaning + shisha completion, audit all transitions.
