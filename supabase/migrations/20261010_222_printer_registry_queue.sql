-- Upgrade 222: universal printer registry and secure, non-executing print queue.
-- Wi-Fi/LAN/Bluetooth/USB/cloud describe gateway capabilities, not guaranteed
-- remote connectivity. No direct device access or printer commands in this migration.
create table if not exists public.gs_cafe_printers (
 id bigint generated always as identity primary key,
 name text not null check(length(trim(name)) between 1 and 120),
 location text not null default '',
 department text not null default 'general',
 connection_type text not null check(connection_type in ('wifi','lan','bluetooth','usb','cloud')),
 paper_width_mm integer not null default 80 check(paper_width_mm in (58,80,210)),
 gateway_key text not null check(length(trim(gateway_key)) between 1 and 120),
 is_enabled boolean not null default true,
 connection_state text not null default 'unknown' check(connection_state in ('unknown','online','offline','error')),
 last_seen_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.gs_cafe_print_jobs (
 id bigint generated always as identity primary key,
 printer_id bigint not null references public.gs_cafe_printers(id),
 document_kind text not null check(document_kind in ('receipt','kitchen_ticket','shisha_ticket','daily_report','other')),
 source_ref text,
 copies integer not null check(copies between 1 and 20),
 status text not null default 'queued' check(status in ('queued','claimed','printed','failed','cancelled','unknown')),
 idempotency_key uuid not null unique,
 requested_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 claimed_at timestamptz, finished_at timestamptz,
 error_message text,
 check ((status <> 'printed') or finished_at is not null)
);
create index if not exists gs_cafe_print_jobs_printer_status_idx
 on public.gs_cafe_print_jobs(printer_id,status,created_at);
alter table public.gs_cafe_printers enable row level security;
alter table public.gs_cafe_print_jobs enable row level security;
revoke all on public.gs_cafe_printers from public,anon,authenticated;
revoke all on public.gs_cafe_print_jobs from public,anon,authenticated;

create or replace function public.gs_list_cafe_printers()
returns table(id bigint,name text,location text,department text,
 connection_type text,paper_width_mm integer,connection_state text,
 last_seen_at timestamptz,is_enabled boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query select p.id,p.name,p.location,p.department,p.connection_type,
 p.paper_width_mm,
 case when p.last_seen_at is null or p.last_seen_at < now()-interval '2 minutes'
  then 'unknown'::text else p.connection_state end,
 p.last_seen_at,p.is_enabled from public.gs_cafe_printers p
 where p.is_enabled order by p.department,p.name;
end; $$;

create or replace function public.gs_list_cafe_print_jobs()
returns table(id bigint,printer_name text,document_kind text,copies integer,
 status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query select j.id,p.name,j.document_kind,j.copies,j.status,j.created_at
 from public.gs_cafe_print_jobs j join public.gs_cafe_printers p on p.id=j.printer_id
 where j.requested_by=auth.uid() or public.gs_can_access('tables','can_edit')
 order by j.created_at desc limit 100;
end; $$;

-- Manager-only registry operation; printer gateway secrets are deliberately not
-- stored in the registry or exposed to clients.
create or replace function public.gs_register_cafe_printer(
 p_name text,p_location text,p_department text,p_connection_type text,
 p_paper_width_mm integer,p_gateway_key text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 insert into public.gs_cafe_printers(name,location,department,connection_type,paper_width_mm,gateway_key)
 values (trim(p_name),coalesce(trim(p_location),''),coalesce(nullif(trim(p_department),''),'general'),
 p_connection_type,p_paper_width_mm,trim(p_gateway_key)) returning id into v_id;
 return v_id;
end; $$;

revoke all on function public.gs_list_cafe_printers() from public,anon;
revoke all on function public.gs_list_cafe_print_jobs() from public,anon;
revoke all on function public.gs_register_cafe_printer(text,text,text,text,integer,text) from public,anon;
grant execute on function public.gs_list_cafe_printers() to authenticated;
grant execute on function public.gs_list_cafe_print_jobs() to authenticated;
grant execute on function public.gs_register_cafe_printer(text,text,text,text,integer,text) to authenticated;
-- IMPORTANT: Queue submission, gateway authentication, status heartbeats,
-- device-specific drivers, retry policy and print acknowledgements remain pending.
