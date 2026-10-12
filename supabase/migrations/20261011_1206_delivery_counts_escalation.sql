-- Upgrade 1206: permission-scoped delivery counts and durable supervisor escalation.
-- Escalations are recorded once per ready/assignment state and remain audit-visible.
create table if not exists public.gs_cafe_replacement_delivery_escalations (
 id bigint generated always as identity primary key,
 revision_id bigint not null references public.gs_cafe_replacement_delivery_tasks(revision_id),
 alert_kind text not null check (alert_kind in ('unassigned','not_accepted','awaiting_pickup','awaiting_delivery')),
 assigned_to uuid references auth.users(id),
 created_at timestamptz not null default transaction_timestamp(),
 resolved_at timestamptz,
 unique (revision_id,alert_kind,created_at)
);
create unique index if not exists gs_replacement_one_active_escalation
 on public.gs_cafe_replacement_delivery_escalations(revision_id)
 where resolved_at is null;
alter table public.gs_cafe_replacement_delivery_escalations enable row level security;
revoke all on public.gs_cafe_replacement_delivery_escalations from public,anon,authenticated;

create or replace function public.gs_replacement_delivery_notification_counts(p_threshold_minutes integer default 15)
returns table(ready_unassigned bigint,my_assigned bigint,my_unaccepted bigint,my_awaiting_pickup bigint,my_awaiting_delivery bigint,overdue_total bigint,supervisor_overdue bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_supervisor boolean;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required'; end if;
 if p_threshold_minutes < 1 or p_threshold_minutes > 240 then raise exception 'Invalid threshold'; end if;
 select exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active) into v_supervisor;
 return query
 select
 count(*) filter(where d.assigned_to is null and (v_supervisor or public.gs_can_work_station(r.station_key))),
 count(*) filter(where d.assigned_to=auth.uid()),
 count(*) filter(where d.assigned_to=auth.uid() and d.accepted_at is null),
 count(*) filter(where d.assigned_to=auth.uid() and d.accepted_at is not null and d.picked_up_at is null),
 count(*) filter(where d.assigned_to=auth.uid() and d.picked_up_at is not null),
 count(*) filter(where r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes)
   and (v_supervisor or d.assigned_to=auth.uid() or (d.assigned_to is null and public.gs_can_work_station(r.station_key)))),
 count(*) filter(where v_supervisor and r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes))
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 where d.delivered_at is null;
end; $$;
revoke all on function public.gs_replacement_delivery_notification_counts(integer) from public,anon;
grant execute on function public.gs_replacement_delivery_notification_counts(integer) to authenticated;

create or replace function public.gs_escalate_overdue_replacement_deliveries(p_threshold_minutes integer default 15)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
 or not exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active) then
 raise exception 'Kitchen supervisor required'; end if;
 if p_threshold_minutes < 1 or p_threshold_minutes > 240 then raise exception 'Invalid threshold'; end if;
 -- Resolve stale alerts on delivery or assignment-state change before inserting new ones.
 update public.gs_cafe_replacement_delivery_escalations e set resolved_at=transaction_timestamp()
 from public.gs_cafe_replacement_delivery_tasks d
 where d.revision_id=e.revision_id and e.resolved_at is null
 and (d.delivered_at is not null or e.assigned_to is distinct from d.assigned_to
   or e.alert_kind is distinct from case when d.assigned_to is null then 'unassigned'
    when d.accepted_at is null then 'not_accepted'
    when d.picked_up_at is null then 'awaiting_pickup' else 'awaiting_delivery' end);
 insert into public.gs_cafe_replacement_delivery_escalations(revision_id,alert_kind,assigned_to)
 select d.revision_id,
 case when d.assigned_to is null then 'unassigned'
 when d.accepted_at is null then 'not_accepted'
 when d.picked_up_at is null then 'awaiting_pickup' else 'awaiting_delivery' end,
 d.assigned_to
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 where d.delivered_at is null and r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes)
 and not exists(select 1 from public.gs_cafe_replacement_delivery_escalations e
 where e.revision_id=d.revision_id and e.resolved_at is null)
 on conflict do nothing;
 get diagnostics v_count=row_count;
 return v_count;
end; $$;
revoke all on function public.gs_escalate_overdue_replacement_deliveries(integer) from public,anon;
grant execute on function public.gs_escalate_overdue_replacement_deliveries(integer) to authenticated;

create or replace function public.gs_replacement_delivery_escalation_inbox(p_limit integer default 100)
returns table(revision_id bigint,order_id bigint,station_key text,alert_kind text,assigned_to uuid,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view')
 or not exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 then raise exception 'Kitchen supervisor required'; end if;
 return query select e.revision_id,r.order_id,r.station_key,e.alert_kind,e.assigned_to,e.created_at
 from public.gs_cafe_replacement_delivery_escalations e
 join public.gs_cafe_correction_station_revisions r on r.id=e.revision_id
 where e.resolved_at is null order by e.created_at desc limit least(greatest(p_limit,1),200);
end; $$;
revoke all on function public.gs_replacement_delivery_escalation_inbox(integer) from public,anon;
grant execute on function public.gs_replacement_delivery_escalation_inbox(integer) to authenticated;
