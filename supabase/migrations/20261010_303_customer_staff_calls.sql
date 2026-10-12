-- Upgrade 303: visit-scoped customer assistance requests.
create table if not exists public.gs_customer_staff_calls (
 id uuid primary key default gen_random_uuid(),
 table_id bigint not null references public.gs_cafe_tables(id),
 visit_id bigint not null,
 call_type text not null check(call_type in ('waiter','cashier','shisha','supervisor','any')),
 note text not null default '' check(length(note)<=300),
 status text not null default 'waiting' check(status in ('waiting','accepted','on_way','completed','cancelled')),
 requested_at timestamptz not null default now(),
 assigned_employee uuid,
 accepted_at timestamptz,
 completed_at timestamptz,
 updated_at timestamptz not null default now()
);
create index if not exists gs_customer_staff_calls_queue_idx
 on public.gs_customer_staff_calls(status,requested_at);
alter table public.gs_customer_staff_calls enable row level security;
revoke all on public.gs_customer_staff_calls from public,anon,authenticated;

create or replace function public.gs_customer_request_employee(
 p_session_token uuid,p_call_type text,p_note text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.gs_customer_visit_sessions%rowtype; v_id uuid;
begin
 select x.* into s from public.gs_customer_visit_sessions x
 join public.gs_cafe_tables t on t.id=x.table_id
 join public.gs_table_visits v on v.id=x.visit_id and v.table_id=x.table_id
 where x.session_token=p_session_token and x.revoked_at is null and x.expires_at>now()
 and t.occupied=true and v.status='open' for update of x;
 if not found then raise exception 'Visit authorization required'; end if;
 if p_call_type not in ('waiter','cashier','shisha','supervisor','any')
 or length(coalesce(p_note,''))>300 then raise exception 'Invalid assistance request'; end if;
 if exists(select 1 from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.table_id=s.table_id and c.status in ('waiting','accepted','on_way')) then
  raise exception 'An assistance request is already active'; end if;
 if (select count(*) from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.requested_at>now()-interval '1 hour')>=5 then
  raise exception 'Too many requests for this visit'; end if;
 insert into public.gs_customer_staff_calls(table_id,visit_id,call_type,note)
 values(s.table_id,s.visit_id,p_call_type,trim(coalesce(p_note,''))) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_customer_request_employee(uuid,text,text) from public;
grant execute on function public.gs_customer_request_employee(uuid,text,text) to anon,authenticated;

create or replace function public.gs_customer_call_status(p_session_token uuid,p_call_id uuid)
returns table(status text,call_type text,requested_at timestamptz,accepted_at timestamptz,completed_at timestamptz)
language sql stable security definer set search_path='' as $$
 select c.status,c.call_type,c.requested_at,c.accepted_at,c.completed_at
 from public.gs_customer_staff_calls c
 join public.gs_customer_visit_sessions s on s.table_id=c.table_id and s.visit_id=c.visit_id
 join public.gs_cafe_tables t on t.id=s.table_id
 join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id
 where s.session_token=p_session_token and s.revoked_at is null and s.expires_at>now()
 and t.occupied and v.status='open' and c.id=p_call_id;
$$;
revoke all on function public.gs_customer_call_status(uuid,uuid) from public;
grant execute on function public.gs_customer_call_status(uuid,uuid) to anon,authenticated;

create or replace function public.gs_staff_customer_call_queue()
returns table(id uuid,table_id bigint,call_type text,note text,status text,requested_at timestamptz,assigned_employee uuid)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
 raise exception 'Not authorized' using errcode='42501'; end if;
 return query select c.id,c.table_id,c.call_type,c.note,c.status,c.requested_at,c.assigned_employee
 from public.gs_customer_staff_calls c
 where c.status in ('waiting','accepted','on_way') order by c.requested_at limit 100;
end $$;
revoke all on function public.gs_staff_customer_call_queue() from public,anon;
grant execute on function public.gs_staff_customer_call_queue() to authenticated;

create or replace function public.gs_staff_update_customer_call(p_id uuid,p_status text)
returns boolean language plpgsql security definer set search_path='' as $$
declare c public.gs_customer_staff_calls%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
 raise exception 'Not authorized' using errcode='42501'; end if;
 select * into c from public.gs_customer_staff_calls where id=p_id for update;
 if not found then raise exception 'Call not found'; end if;
 if not ((c.status='waiting' and p_status in ('accepted','cancelled'))
 or (c.status='accepted' and p_status in ('on_way','completed'))
 or (c.status='on_way' and p_status='completed')) then
 raise exception 'Invalid call transition'; end if;
 if c.assigned_employee is not null and c.assigned_employee<>auth.uid() then
 raise exception 'Assigned to another employee'; end if;
 update public.gs_customer_staff_calls set status=p_status,
 assigned_employee=case when p_status='cancelled' then assigned_employee else auth.uid() end,
 accepted_at=case when p_status='accepted' then now() else accepted_at end,
 completed_at=case when p_status in ('completed','cancelled') then now() else completed_at end,
 updated_at=now() where id=p_id;
 return true;
end $$;
revoke all on function public.gs_staff_update_customer_call(uuid,text) from public,anon;
grant execute on function public.gs_staff_update_customer_call(uuid,text) to authenticated;
