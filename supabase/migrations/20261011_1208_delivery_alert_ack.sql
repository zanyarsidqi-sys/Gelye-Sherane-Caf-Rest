-- Upgrade 1208: durable per-employee notification acknowledgments.
-- Escalation runs during supervisor polling; time passing alone cannot fire a DB trigger.
create table if not exists public.gs_cafe_replacement_delivery_ack (
 revision_id bigint not null references public.gs_cafe_replacement_delivery_tasks(revision_id),
 employee_id uuid not null references auth.users(id),
 assignment_at timestamptz not null,
 acknowledged_at timestamptz not null default transaction_timestamp(),
 primary key(revision_id,employee_id,assignment_at)
);
alter table public.gs_cafe_replacement_delivery_ack enable row level security;
revoke all on public.gs_cafe_replacement_delivery_ack from public,anon,authenticated;

create or replace function public.gs_ack_replacement_delivery_notification(p_revision_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare d public.gs_cafe_replacement_delivery_tasks%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen permission required'; end if;
 select * into d from public.gs_cafe_replacement_delivery_tasks where revision_id=p_revision_id for update;
 if not found or d.assigned_to is distinct from auth.uid() or d.assigned_at is null or d.delivered_at is not null then
  raise exception 'Active assigned notification required'; end if;
 insert into public.gs_cafe_replacement_delivery_ack(revision_id,employee_id,assignment_at)
 values(p_revision_id,auth.uid(),d.assigned_at) on conflict do nothing;
end; $$;
revoke all on function public.gs_ack_replacement_delivery_notification(bigint) from public,anon;
grant execute on function public.gs_ack_replacement_delivery_notification(bigint) to authenticated;

create or replace function public.gs_my_replacement_delivery_notifications()
returns table(revision_id bigint,order_id bigint,station_key text,assignment_at timestamptz,
 acknowledged_at timestamptz,delivery_status text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
  raise exception 'Kitchen permission required'; end if;
 return query select d.revision_id,r.order_id,r.station_key,d.assigned_at,a.acknowledged_at,
 (case when d.accepted_at is null then 'Awaiting acceptance'
 when d.picked_up_at is null then 'Awaiting pickup' else 'Out for delivery' end)::text
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 left join public.gs_cafe_replacement_delivery_ack a on a.revision_id=d.revision_id
 and a.employee_id=auth.uid() and a.assignment_at=d.assigned_at
 where d.assigned_to=auth.uid() and d.delivered_at is null
 order by (a.acknowledged_at is null) desc,d.assigned_at asc limit 100;
end; $$;
revoke all on function public.gs_my_replacement_delivery_notifications() from public,anon;
grant execute on function public.gs_my_replacement_delivery_notifications() to authenticated;

-- Supervisor polling can create escalation records automatically without an explicit button.
-- This wrapper preserves the supervisor-only permission checks in the existing RPC.
create or replace function public.gs_supervisor_auto_escalation_poll(p_threshold_minutes integer default 15)
returns integer language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
 or not exists(select 1 from public.gs_cafe_station_supervisors s
 where s.employee_id=auth.uid() and s.active) then
 raise exception 'Kitchen supervisor required'; end if;
 return public.gs_escalate_overdue_replacement_deliveries(p_threshold_minutes);
end; $$;
revoke all on function public.gs_supervisor_auto_escalation_poll(integer) from public,anon;
grant execute on function public.gs_supervisor_auto_escalation_poll(integer) to authenticated;
