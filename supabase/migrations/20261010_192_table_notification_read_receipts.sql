-- Upgrade 192: per-employee read receipts for shared and targeted table events.
create table if not exists public.gs_table_notification_reads (
 notification_id bigint not null references public.gs_table_work_notifications(id) on delete cascade,
 employee_id uuid not null references auth.users(id),
 read_at timestamptz not null default now(),
 primary key(notification_id,employee_id)
);
alter table public.gs_table_notification_reads enable row level security;
revoke all on public.gs_table_notification_reads from public,anon,authenticated;

create or replace function public.gs_list_my_table_notifications()
returns table(id bigint,event_type text,table_number integer,message text,
 created_at timestamptz,job_id bigint,is_read boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_view') or
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view')) then
  raise exception 'Not authorized to view notifications'; end if;
 return query select n.id,n.event_type,n.table_number,n.message,
  n.created_at,n.job_id,(r.employee_id is not null)
 from public.gs_table_work_notifications n
 left join public.gs_table_notification_reads r
  on r.notification_id=n.id and r.employee_id=auth.uid()
 where n.recipient_employee is null or n.recipient_employee=auth.uid()
 order by n.created_at desc limit 100;
end; $$;
revoke all on function public.gs_list_my_table_notifications() from public,anon;
grant execute on function public.gs_list_my_table_notifications() to authenticated;

create or replace function public.gs_mark_my_table_notification_read(p_id bigint)
returns boolean language plpgsql volatile security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_view') or
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view')) then
  raise exception 'Not authorized to acknowledge notifications'; end if;
 if not exists (select 1 from public.gs_table_work_notifications n
  where n.id=p_id and (n.recipient_employee is null or
    n.recipient_employee=auth.uid())) then
  raise exception 'Notification not accessible'; end if;
 insert into public.gs_table_notification_reads(notification_id,employee_id)
 values(p_id,auth.uid()) on conflict do nothing;
 return true;
end; $$;
revoke all on function public.gs_mark_my_table_notification_read(bigint) from public,anon;
grant execute on function public.gs_mark_my_table_notification_read(bigint) to authenticated;
