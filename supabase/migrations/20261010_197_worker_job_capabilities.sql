-- Upgrade 197: department eligibility enforced in claim/reassignment RPCs.
-- Explicit job-type grants. No direct client mutation of grants.
create table if not exists public.gs_table_worker_capabilities (
 employee_user_id uuid not null references auth.users(id),
 job_kind text not null check (job_kind in (
  'take_order','deliver_items','clean','shisha_service',
  'tea_service','bring_bill','other')),
 granted_by uuid references auth.users(id),
 granted_at timestamptz not null default now(),
 primary key(employee_user_id,job_kind)
);
alter table public.gs_table_worker_capabilities enable row level security;
revoke all on public.gs_table_worker_capabilities from public,anon,authenticated;

create or replace function public.gs_can_work_table_job(p_user_id uuid,p_kind text)
returns boolean language sql stable security definer set search_path='' as $$
 select public.gs_is_active_table_worker(p_user_id)
 and exists (select 1 from public.gs_table_worker_capabilities c
   where c.employee_user_id=p_user_id and c.job_kind=p_kind)
 and exists (select 1 from public.employee_profiles p
   where p.user_id=p_user_id and p.is_active=true);
$$;
revoke all on function public.gs_can_work_table_job(uuid,text) from public,anon,authenticated;

-- Authorized managers configure capability grants. A single RPC is the
-- only client-accessible path to grant/revoke, with a change audit.
create table if not exists public.gs_table_worker_capability_events (
 id bigint generated always as identity primary key,
 employee_user_id uuid not null references auth.users(id),
 job_kind text not null,
 enabled boolean not null,
 actor uuid not null references auth.users(id),
 happened_at timestamptz not null default now()
);
alter table public.gs_table_worker_capability_events enable row level security;
revoke all on public.gs_table_worker_capability_events from public,anon,authenticated;
create or replace function public.gs_set_table_worker_capability(
 p_employee uuid,p_kind text,p_enabled boolean)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('employees','can_edit') then
  raise exception 'Employee management permission required';
 end if;
 if p_kind not in ('take_order','deliver_items','clean','shisha_service',
                   'tea_service','bring_bill','other') or p_enabled is null then
  raise exception 'Invalid job capability';
 end if;
 if not public.gs_is_active_table_worker(p_employee) then
  raise exception 'Employee must be active';
 end if;
 if p_enabled then
  insert into public.gs_table_worker_capabilities(employee_user_id,job_kind,granted_by)
  values(p_employee,p_kind,auth.uid()) on conflict do nothing;
 else
  delete from public.gs_table_worker_capabilities
  where employee_user_id=p_employee and job_kind=p_kind;
 end if;
 insert into public.gs_table_worker_capability_events(
  employee_user_id,job_kind,enabled,actor)
 values(p_employee,p_kind,p_enabled,auth.uid());
end; $$;
revoke all on function public.gs_set_table_worker_capability(uuid,text,boolean) from public,anon;
grant execute on function public.gs_set_table_worker_capability(uuid,text,boolean) to authenticated;

-- Harden existing claim and reassignment functions without replacing
-- their notification logic, lock handling or audit trails.
-- Trigger executes under the same transaction and rejects unauthorized
-- assignment even if an older RPC implementation is invoked.
create or replace function public.gs_validate_table_job_assignee()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.assigned_to is not null and
   (tg_op='INSERT' or old.assigned_to is distinct from new.assigned_to) then
  if not public.gs_can_work_table_job(new.assigned_to,new.kind) then
   raise exception 'Employee is not eligible for job type %',new.kind;
  end if;
 end if;
 return new;
end; $$;
drop trigger if exists gs_validate_table_job_assignee_trigger on public.gs_table_service_jobs;
create trigger gs_validate_table_job_assignee_trigger
before insert or update of assigned_to,kind on public.gs_table_service_jobs
for each row execute function public.gs_validate_table_job_assignee();
-- Existing employees are NOT auto-granted sensitive capabilities.
-- Managers must explicitly assign job kinds before claiming can succeed.
