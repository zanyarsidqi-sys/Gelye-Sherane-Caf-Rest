-- Staged schema: CLI unavailable here. Apply and validate in staging, then
-- generate an official migration with `supabase migration new browser_push`.
begin;
create table public.gs_browser_push_subscriptions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 session_id uuid not null,
 endpoint text not null unique check(length(endpoint) <= 2048),
 p256dh text not null,
 auth_key text not null,
 expires_at timestamptz,
 last_test_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.gs_browser_push_subscriptions enable row level security;
revoke all on public.gs_browser_push_subscriptions from public, anon, authenticated;
grant select,insert,update,delete on public.gs_browser_push_subscriptions to service_role;
create table public.gs_browser_push_jobs (
 id bigint generated always as identity primary key,
 subscription_id uuid not null references public.gs_browser_push_subscriptions(id) on delete cascade,
 source_table text not null,
 source_id bigint not null,
 section_key text not null,
 status text not null default 'pending' check(status in ('pending','processing','sent','failed')),
 attempts integer not null default 0,
 available_at timestamptz not null default now(),
 lease_id uuid,
 created_at timestamptz not null default now(),
 unique(subscription_id,source_table,source_id)
);
alter table public.gs_browser_push_jobs enable row level security;
revoke all on public.gs_browser_push_jobs from public,anon,authenticated;
grant select,insert,update,delete on public.gs_browser_push_jobs to service_role;
grant usage,select on sequence public.gs_browser_push_jobs_id_seq to service_role;
create index gs_browser_push_jobs_pending on public.gs_browser_push_jobs(available_at) where status in ('pending','processing');

grant select on public.employee_profiles, public.employee_section_permissions,
 public.gs_app_releases, public.gs_app_release_events to service_role;

create schema if not exists gs_push_private;
revoke all on schema gs_push_private from public,anon,authenticated;
-- Only internal triggers may enqueue; recipient identity comes from durable
-- notification rows created by existing application authorization workflows.
create function gs_push_private.enqueue() returns trigger
language plpgsql security definer set search_path='' as $$
declare recipient uuid; section text;
begin
 if auth.uid() is null and coalesce(auth.role(),'') <> 'service_role' then
   raise exception 'Authenticated notification writer required';
 end if;
 if tg_table_name='gs_service_task_notifications' then
   recipient := new.recipient_id; section := 'table_orders';
 elsif tg_table_name='gs_cafe_station_notifications' then
   recipient := new.employee_id; section := 'kitchen';
 else raise exception 'Unsupported notification source'; end if;
 insert into public.gs_browser_push_jobs(subscription_id,source_table,source_id,section_key)
 select s.id,tg_table_name,new.id,section from public.gs_browser_push_subscriptions s
 where s.user_id=recipient and (s.expires_at is null or s.expires_at>now())
 on conflict do nothing;
 return new;
end $$;
revoke all on function gs_push_private.enqueue() from public,anon,authenticated;
create trigger gs_service_browser_push after insert on public.gs_service_task_notifications
 for each row execute function gs_push_private.enqueue();
create trigger gs_station_browser_push after insert on public.gs_cafe_station_notifications
 for each row execute function gs_push_private.enqueue();

-- Release announcements are queued only by the authoritative publication event.
-- Draft edits and ready-for-review transitions never notify employees.
create function gs_push_private.release_published() returns trigger
language plpgsql security definer set search_path='' as $$
declare release public.gs_app_releases;
begin
 if auth.uid() is null and coalesce(auth.role(),'') <> 'service_role' then
   raise exception 'Authenticated release publisher required';
 end if;
 if new.action <> 'publish' then return new; end if;
 select * into release from public.gs_app_releases where id=new.release_id;
 if release.status <> 'published' or release.platform <> 'web' or release.channel <> 'stable' then return new; end if;
 insert into public.gs_browser_push_jobs(subscription_id,source_table,source_id,section_key)
 select s.id,'gs_app_release_events',new.id,'notifications'
 from public.gs_browser_push_subscriptions s
 where s.expires_at is null or s.expires_at>now()
 on conflict do nothing;
 return new;
end $$;
revoke all on function gs_push_private.release_published() from public,anon,authenticated;
create trigger gs_published_release_browser_push after insert on public.gs_app_release_events
 for each row execute function gs_push_private.release_published();

-- Definer is necessary to read auth.sessions; RPC is service-role only.
create function public.gs_browser_push_eligible(p_subscription uuid, p_section text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists (
 select 1 from public.gs_browser_push_subscriptions s
 join auth.sessions a on a.id=s.session_id and a.user_id=s.user_id
 join public.employee_profiles e on e.user_id=s.user_id and e.is_active
 where s.id=p_subscription and (s.expires_at is null or s.expires_at>now())
 and (a.not_after is null or a.not_after>now())
 and exists(select 1 from public.employee_section_permissions p
   where p.user_id=s.user_id and p.section_key='dashboard' and p.can_view)
 and exists(select 1 from public.employee_section_permissions p
   where p.user_id=s.user_id and p.section_key=p_section and p.can_view)
 );
$$;
revoke all on function public.gs_browser_push_eligible(uuid,text) from public,anon,authenticated;
grant execute on function public.gs_browser_push_eligible(uuid,text) to service_role;
create function public.gs_claim_browser_push_jobs() returns setof public.gs_browser_push_jobs
language sql security invoker set search_path='' as $$
 with abandoned as (
 update public.gs_browser_push_jobs set status='failed'
 where status='processing' and available_at<=now() and attempts>=5 returning id
 )
 update public.gs_browser_push_jobs j set status='processing',attempts=j.attempts+1,
 lease_id=gen_random_uuid(), available_at=now()+interval '2 minutes'
 where j.id in (
 select q.id from public.gs_browser_push_jobs q where q.status in ('pending','processing')
 and q.available_at<=now() and q.attempts<5
 order by q.id for update skip locked limit 10
 ) returning j.*;
$$;
revoke all on function public.gs_claim_browser_push_jobs() from public,anon,authenticated;
grant execute on function public.gs_claim_browser_push_jobs() to service_role;
commit;
