-- Upgrade 201: transaction-safe workload limits by job responsibility.
-- A limit of 0 disables new assignments of that kind; default is 5.
create table if not exists public.gs_table_job_workload_limits (
 job_kind text primary key check(job_kind in
 ('take_order','deliver_items','clean','shisha_service','tea_service','bring_bill','other')),
 max_active integer not null check(max_active between 0 and 100),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
insert into public.gs_table_job_workload_limits(job_kind,max_active)
select kind,5 from (values ('take_order'),('deliver_items'),('clean'),
 ('shisha_service'),('tea_service'),('bring_bill'),('other')) v(kind)
on conflict(job_kind) do nothing;
alter table public.gs_table_job_workload_limits enable row level security;
revoke all on public.gs_table_job_workload_limits from public,anon,authenticated;

create table if not exists public.gs_table_job_limit_events (
 id bigint generated always as identity primary key,
 job_kind text not null, old_limit integer not null, new_limit integer not null,
 actor uuid not null references auth.users(id), changed_at timestamptz not null default now()
);
alter table public.gs_table_job_limit_events enable row level security;
revoke all on public.gs_table_job_limit_events from public,anon,authenticated;

create or replace function public.gs_list_table_job_workload_limits()
returns table(job_kind text,max_active integer,currently_assigned bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 return query select l.job_kind,l.max_active,
  (select count(*) from public.gs_table_service_jobs j
   where j.kind=l.job_kind and j.status in ('assigned','in_progress'))::bigint
 from public.gs_table_job_workload_limits l order by l.job_kind;
end; $$;
revoke all on function public.gs_list_table_job_workload_limits() from public,anon;
grant execute on function public.gs_list_table_job_workload_limits() to authenticated;

create or replace function public.gs_set_table_job_workload_limit(p_kind text,p_limit integer)
returns void language plpgsql volatile security definer set search_path='' as $$
declare v_old integer;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_limit is null or p_limit not between 0 and 100 then
  raise exception 'Limit must be between 0 and 100';
 end if;
 select l.max_active into v_old from public.gs_table_job_workload_limits l
 where l.job_kind=p_kind for update;
 if not found then raise exception 'Unknown job responsibility'; end if;
 update public.gs_table_job_workload_limits set max_active=p_limit,
  updated_by=auth.uid(),updated_at=now() where job_kind=p_kind;
 if v_old is distinct from p_limit then
  insert into public.gs_table_job_limit_events(job_kind,old_limit,new_limit,actor)
  values(p_kind,v_old,p_limit,auth.uid());
 end if;
end; $$;
revoke all on function public.gs_set_table_job_workload_limit(text,integer) from public,anon;
grant execute on function public.gs_set_table_job_workload_limit(text,integer) to authenticated;

-- Lock the assignee's employee profile row to serialize simultaneous job claims
-- and reassignments to the same employee across independent transactions.
-- Existing active assignments are not retroactively invalidated if a limit drops.
create or replace function public.gs_enforce_table_job_workload()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_limit integer; v_count bigint;
begin
 if new.assigned_to is null or new.status not in ('assigned','in_progress') then
  return new;
 end if;
 if tg_op='UPDATE' and old.assigned_to is not distinct from new.assigned_to
  and old.kind is not distinct from new.kind
  and old.status in ('assigned','in_progress') then
  return new;
 end if;
 -- Consistent serialization point for concurrent claims to same employee.
 perform 1 from public.employee_profiles p
 where p.user_id=new.assigned_to for update;
 if not found then raise exception 'Employee profile not found'; end if;
 select l.max_active into v_limit from public.gs_table_job_workload_limits l
 where l.job_kind=new.kind;
 if v_limit is null then raise exception 'Job workload limit is not configured'; end if;
 select count(*) into v_count from public.gs_table_service_jobs j
 where j.assigned_to=new.assigned_to and j.kind=new.kind
  and j.status in ('assigned','in_progress')
  and j.id is distinct from new.id;
 if v_count>=v_limit then
  raise exception 'Employee workload limit reached for % (% active / % allowed)',
    new.kind,v_count,v_limit;
 end if;
 return new;
end; $$;
drop trigger if exists gs_enforce_table_job_workload_trg on public.gs_table_service_jobs;
create trigger gs_enforce_table_job_workload_trg
before insert or update of assigned_to,kind,status on public.gs_table_service_jobs
for each row execute function public.gs_enforce_table_job_workload();
