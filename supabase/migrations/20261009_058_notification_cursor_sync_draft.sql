-- Dashboard Upgrade 57 — employee-scoped notification sync foundation (DRAFT).
-- Does not enable background push or offline writes.
-- Uses a stable (created_at,id) cursor to avoid missing same-timestamp events.
create or replace function public.gs_my_service_notifications_since(
 p_after_created_at timestamptz default null,
 p_after_id bigint default 0,
 p_limit integer default 100
)
returns table(
 id bigint, task_id bigint, event_type text,
 created_at timestamptz, read_at timestamptz
)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 if p_after_created_at is null and coalesce(p_after_id,0)<>0 then
   raise exception 'A notification cursor requires its timestamp';
 end if;
 return query
 select n.id,n.task_id,n.event_type,n.created_at,n.read_at
 from public.gs_service_task_notifications n
 where n.recipient_id=auth.uid()
   and (p_after_created_at is null or
        (n.created_at,n.id) > (p_after_created_at,coalesce(p_after_id,0)))
 order by n.created_at asc,n.id asc
 limit least(greatest(coalesce(p_limit,100),1),250);
end; $$;
revoke all on function public.gs_my_service_notifications_since(timestamptz,bigint,integer)
 from public,anon;
grant execute on function public.gs_my_service_notifications_since(timestamptz,bigint,integer)
 to authenticated;

create or replace function public.gs_my_service_notification_summary()
returns table(unread_count bigint, latest_notification_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 return query
 select count(*) filter (where n.read_at is null)::bigint,
        max(n.created_at)
 from public.gs_service_task_notifications n
 where n.recipient_id=auth.uid();
end; $$;
revoke all on function public.gs_my_service_notification_summary()
 from public,anon;
grant execute on function public.gs_my_service_notification_summary()
 to authenticated;

-- Critical: read_at changes are not part of the immutable creation cursor.
-- Clients must refresh read state via full inbox/summary or a future
-- updated_at-based change stream. Offline mutations MUST NOT be accepted
-- as payment, table release, owner approval or bill transfer.
