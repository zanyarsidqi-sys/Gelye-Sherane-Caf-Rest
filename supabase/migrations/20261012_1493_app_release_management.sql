begin;
create table public.gs_app_releases (
 id bigint generated always as identity primary key,
 platform text not null check(platform in ('web','android','ios','windows')),
 channel text not null check(channel in ('test','stable')),
 version text not null check(version ~ '^[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,9}$'),
 notes text not null check(length(notes) between 10 and 4000),
 artifact_url text not null check(length(artifact_url) <= 1000),
 sha256 text not null check(sha256 ~ '^[a-f0-9]{64}$'),
 status text not null default 'draft' check(status in ('draft','ready','published','superseded','withdrawn')),
 revision integer not null default 1,
 checks jsonb not null default '{}',
 previous_release_id bigint references public.gs_app_releases(id),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(platform,channel,version)
);
create unique index gs_app_one_current_release on public.gs_app_releases(platform,channel) where status='published';
create table public.gs_app_release_events (
 id bigint generated always as identity primary key,
 release_id bigint not null references public.gs_app_releases(id),
 actor_id uuid not null references auth.users(id),
 request_id text not null,
 request_payload jsonb not null,
 action text not null,
 reason text not null,
 before_state jsonb,
 after_state jsonb not null,
 created_at timestamptz not null default now(),
 unique(actor_id, request_id)
);
alter table public.gs_app_releases enable row level security;
alter table public.gs_app_release_events enable row level security;
revoke all on public.gs_app_releases, public.gs_app_release_events from anon,authenticated;
grant select on public.gs_app_releases, public.gs_app_release_events to authenticated;
create function public.gs_app_release_access(p_action text) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and coalesce(auth.jwt()->>'aal','')='aal2'
 and public.gs_can_access('app_publishing_updates','can_view')
 and public.gs_can_access('app_publishing_updates',p_action);
$$;
revoke all on function public.gs_app_release_access(text) from public, anon;
grant execute on function public.gs_app_release_access(text) to authenticated;
create policy app_release_read on public.gs_app_releases for select to authenticated
 using(public.gs_app_release_access('can_view'));
create policy app_release_events_read on public.gs_app_release_events for select to authenticated
 using(public.gs_app_release_access('can_view'));

create function public.gs_app_release_create(p_draft jsonb,p_request_id text) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_id bigint; v_row public.gs_app_releases; v_event public.gs_app_release_events;
 v_url text:=p_draft->>'artifact_url'; v_sha text:=lower(p_draft->>'sha256');
begin
 if not public.gs_app_release_access('can_create') then raise exception 'Release creation permission and MFA required' using errcode='42501'; end if;
 if p_request_id is null or p_request_id !~ '^[a-f0-9]{48}$' then raise exception 'Invalid request ID'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request_id,0));
 select * into v_event from public.gs_app_release_events where actor_id=auth.uid() and request_id=p_request_id;
 if found then
  if v_event.action <> 'create' or v_event.request_payload is distinct from p_draft then raise exception 'Request ID reused for different input'; end if;
  return v_event.release_id;
 end if;
 -- Only known distribution hosts. No signed URLs, credentials or arbitrary schemes.
 if v_url is null or v_url !~ '^https://(cafe\.gelyesheranecompany\.com(/[^?#[:space:]]*)?|github\.com/zanyarsidqi-sys/Gelye-Sherane-Caf-Rest/releases/[^?#[:space:]]+|apps\.apple\.com/[^?#[:space:]]+|play\.google\.com/store/apps/[^?#[:space:]]+|apps\.microsoft\.com/[^?#[:space:]]+)$' then
  raise exception 'Use an approved HTTPS distribution URL without query or fragment';
 end if;
 insert into public.gs_app_releases(platform,channel,version,notes,artifact_url,sha256,created_by)
 values(p_draft->>'platform',p_draft->>'channel',p_draft->>'version',trim(p_draft->>'notes'),v_url,v_sha,auth.uid()) returning * into v_row;
 insert into public.gs_app_release_events(release_id,actor_id,request_id,request_payload,action,reason,after_state)
 values(v_row.id,auth.uid(),p_request_id,p_draft,'create','Release draft created',to_jsonb(v_row));
 return v_row.id;
end; $$;

create function public.gs_app_release_transition(p_id bigint,p_revision integer,p_action text,p_reason text,p_checks jsonb,p_request_id text) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_row public.gs_app_releases; v_after public.gs_app_releases; v_previous public.gs_app_releases;
 v_current public.gs_app_releases; v_event public.gs_app_release_events; v_payload jsonb; v_key text;
begin
 if not public.gs_app_release_access('can_edit') then raise exception 'Release edit permission and MFA required' using errcode='42501'; end if;
 if p_request_id is null or p_request_id !~ '^[a-f0-9]{48}$' then raise exception 'Invalid request ID'; end if;
 if p_reason is null or length(trim(p_reason)) not between 10 and 1000 then raise exception 'Provide a reason of 10–1000 characters'; end if;
 if p_action is null or p_action not in ('ready','publish','withdraw','rollback') then raise exception 'Invalid release action'; end if;
 v_payload:=jsonb_build_object('id',p_id,'revision',p_revision,'action',p_action,'reason',p_reason,'checks',p_checks);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request_id,0));
 select * into v_event from public.gs_app_release_events where actor_id=auth.uid() and request_id=p_request_id;
 if found then
  if v_event.request_payload is distinct from v_payload then raise exception 'Request ID reused for different input'; end if;
  return v_event.release_id;
 end if;
 select * into v_row from public.gs_app_releases where id=p_id;
 if not found then raise exception 'Release not found'; end if;
 -- Serialize transitions for the whole platform/channel, including publication and rollback.
 perform pg_advisory_xact_lock(hashtextextended('app-release:'||v_row.platform||':'||v_row.channel,0));
 select * into v_row from public.gs_app_releases where id=p_id for update;
 if p_revision is null or v_row.revision <> p_revision then raise exception 'Release changed. Refresh before retrying' using errcode='40001'; end if;
 if p_action='ready' then
  if v_row.status <> 'draft' then raise exception 'Only drafts can be reviewed'; end if;
  foreach v_key in array array['smoke','permissions','backend','backup','artifact'] loop
   if p_checks->v_key is distinct from 'true'::jsonb then raise exception 'All release review checks are required'; end if;
  end loop;
  update public.gs_app_releases set status='ready',checks=p_checks,revision=revision+1,updated_at=now() where id=p_id;
 elsif p_action='publish' then
  if v_row.status <> 'ready' then raise exception 'Only reviewed releases can be made available'; end if;
  select * into v_current from public.gs_app_releases where platform=v_row.platform and channel=v_row.channel and status='published' for update;
  if found then
   if string_to_array(v_row.version,'.')::bigint[] <= string_to_array(v_current.version,'.')::bigint[] then
    raise exception 'New release version must exceed the current version. Use rollback for recovery';
   end if;
   update public.gs_app_releases set status='superseded',revision=revision+1,updated_at=now() where id=v_current.id;
  end if;
  update public.gs_app_releases set status='published',previous_release_id=v_current.id,revision=revision+1,updated_at=now() where id=p_id;
 elsif p_action='withdraw' then
  if v_row.status not in ('draft','ready') then raise exception 'Only unpublished releases can be withdrawn'; end if;
  update public.gs_app_releases set status='withdrawn',revision=revision+1,updated_at=now() where id=p_id;
 else
  if v_row.status <> 'published' or v_row.previous_release_id is null then raise exception 'No previous available release to restore'; end if;
  select * into v_previous from public.gs_app_releases where id=v_row.previous_release_id for update;
  if v_previous.status <> 'superseded' or v_previous.platform <> v_row.platform or v_previous.channel <> v_row.channel then raise exception 'Previous release is not eligible for rollback'; end if;
  update public.gs_app_releases set status='withdrawn',revision=revision+1,updated_at=now() where id=p_id;
  update public.gs_app_releases set status='published',revision=revision+1,updated_at=now() where id=v_previous.id;
 end if;
 select * into v_after from public.gs_app_releases where id=p_id;
 insert into public.gs_app_release_events(release_id,actor_id,request_id,request_payload,action,reason,before_state,after_state)
 values(p_id,auth.uid(),p_request_id,v_payload,p_action,trim(p_reason),to_jsonb(v_row),jsonb_build_object('release',to_jsonb(v_after),'previous_release',case when p_action='rollback' then (select to_jsonb(r) from public.gs_app_releases r where r.id=v_previous.id) else null end,'superseded_release',case when p_action='publish' and v_current.id is not null then (select to_jsonb(r) from public.gs_app_releases r where r.id=v_current.id) else null end));
 return p_id;
end; $$;
revoke all on function public.gs_app_release_create(jsonb,text), public.gs_app_release_transition(bigint,integer,text,text,jsonb,text) from public, anon;
grant execute on function public.gs_app_release_create(jsonb,text), public.gs_app_release_transition(bigint,integer,text,text,jsonb,text) to authenticated;
-- Minimal update notices for active signed-in employees across all sections.
-- No publication mutation is exposed here; incomplete reviews never appear.
create function public.gs_app_available_update(p_platform text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2' or not exists (
  select 1 from public.employee_profiles where user_id=auth.uid() and is_active=true
 ) then raise exception 'Active MFA employee session required' using errcode='42501'; end if;
 if p_platform is null or p_platform not in ('web','android','ios','windows') then raise exception 'Invalid platform'; end if;
 select jsonb_build_object('id',id,'version',version,'notes',notes,'revision',revision)
 into v_result from public.gs_app_releases where platform=p_platform and channel='stable' and status='published';
 return v_result;
end; $$;
revoke all on function public.gs_app_available_update(text) from public, anon;
grant execute on function public.gs_app_available_update(text) to authenticated;
commit;
