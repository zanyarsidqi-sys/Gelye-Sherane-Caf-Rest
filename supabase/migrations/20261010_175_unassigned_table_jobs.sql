-- Upgrade 175: claimable table service jobs and transactional notification events.
-- Task management only; never changes order, payment or delivery state.
create table if not exists public.gs_table_service_jobs (
 id bigint generated always as identity primary key,
 table_number integer not null references public.gs_cafe_tables(table_number),
 visit_id bigint references public.gs_table_visits(id),
 kind text not null check(kind in
  ('take_order','deliver_items','clean','shisha_service','tea_service','bring_bill','other')),
 details text not null default '',
 priority text not null default 'normal' check(priority in ('normal','high','urgent')),
 due_at timestamptz,
 status text not null default 'unassigned' check(status in
  ('unassigned','assigned','in_progress','completed','cancelled')),
 assigned_to uuid references auth.users(id),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 claimed_at timestamptz,
 completed_at timestamptz,
 constraint gs_job_assignment_consistency check (
  (status='unassigned' and assigned_to is null) or
  (status in ('assigned','in_progress','completed') and assigned_to is not null) or
  status='cancelled')
);
create index if not exists gs_table_jobs_queue_idx
 on public.gs_table_service_jobs(status,priority,due_at,created_at);
alter table public.gs_table_service_jobs enable row level security;
revoke all on public.gs_table_service_jobs from public,anon,authenticated;

create table if not exists public.gs_table_service_job_events (
 id bigint generated always as identity primary key,
 job_id bigint not null references public.gs_table_service_jobs(id),
 event_kind text not null,
 actor uuid not null references auth.users(id),
 recipient uuid references auth.users(id),
 happened_at timestamptz not null default now(),
 details jsonb not null default '{}'::jsonb
);
create index if not exists gs_table_job_events_job_idx
 on public.gs_table_service_job_events(job_id,happened_at);
alter table public.gs_table_service_job_events enable row level security;
revoke all on public.gs_table_service_job_events from public,anon,authenticated;
-- These are durable notification events, to be dispatched by a later worker.
-- No claim of push notification delivery until dispatch is implemented.
create or replace function public.gs_claim_table_service_job(p_job_id bigint)
returns table(job_id bigint,assigned_employee uuid,new_status text,event_id bigint)
language plpgsql volatile security definer set search_path='' as $$
declare v_job public.gs_table_service_jobs%rowtype;
 v_event bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Not authorized to claim table jobs';
 end if;
 select * into v_job from public.gs_table_service_jobs
 where id=p_job_id for update;
 if not found then raise exception 'Job not found'; end if;
 if v_job.status<>'unassigned' or v_job.assigned_to is not null then
  raise exception 'Job is no longer available';
 end if;
 update public.gs_table_service_jobs
 set status='assigned',assigned_to=auth.uid(),claimed_at=now()
 where id=v_job.id;
 insert into public.gs_table_service_job_events(
  job_id,event_kind,actor,recipient,details)
 values(v_job.id,'job_claimed',auth.uid(),v_job.created_by,
  jsonb_build_object('table_number',v_job.table_number,
                     'kind',v_job.kind,'claimed_by',auth.uid()))
 returning id into v_event;
 return query select v_job.id,auth.uid(),'assigned'::text,v_event;
end; $$;
revoke all on function public.gs_claim_table_service_job(bigint) from public,anon;
grant execute on function public.gs_claim_table_service_job(bigint) to authenticated;

create or replace function public.gs_list_unassigned_table_jobs()
returns table(job_id bigint,table_number integer,kind text,details text,
 priority text,due_at timestamptz,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Not authorized to view table jobs';
 end if;
 return query select j.id,j.table_number,j.kind,j.details,j.priority,
  j.due_at,j.created_at from public.gs_table_service_jobs j
 where j.status='unassigned'
 order by case j.priority when 'urgent' then 0 when 'high' then 1 else 2 end,
  j.due_at nulls last,j.created_at limit 200;
end; $$;
revoke all on function public.gs_list_unassigned_table_jobs() from public,anon;
grant execute on function public.gs_list_unassigned_table_jobs() to authenticated;

create or replace function public.gs_create_table_service_job(
 p_table_number integer,p_kind text,p_details text,p_priority text,
 p_due_at timestamptz default null)
returns bigint
language plpgsql volatile security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Not authorized to create table jobs';
 end if;
 if not exists(select 1 from public.gs_cafe_tables t
   where t.table_number=p_table_number) then raise exception 'Table not found'; end if;
 insert into public.gs_table_service_jobs(
  table_number,kind,details,priority,due_at,created_by)
 values(p_table_number,p_kind,left(coalesce(p_details,''),1000),
  p_priority,p_due_at,auth.uid()) returning id into v_id;
 insert into public.gs_table_service_job_events(job_id,event_kind,actor,details)
 values(v_id,'job_created',auth.uid(),
  jsonb_build_object('table_number',p_table_number,'kind',p_kind));
 return v_id;
end; $$;
revoke all on function public.gs_create_table_service_job(integer,text,text,text,timestamptz)
 from public,anon;
grant execute on function public.gs_create_table_service_job(integer,text,text,text,timestamptz)
 to authenticated;
