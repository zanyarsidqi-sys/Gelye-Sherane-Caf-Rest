-- STAGING FIRST. Prevent repeat publication announcements for a single release.
-- A release can be published only once; rollback uses a separate event action.
begin;
create unique index if not exists gs_release_publish_once_per_release
 on public.gs_app_release_events(release_id) where action = 'publish';
-- A publication event must correspond to an actual change from ready to published.
-- This protects against forged events using an already-published release.
create or replace function public.gs_app_release_publish_gate() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_release public.gs_app_releases;
begin
 if new.action <> 'publish' then return new; end if;
 if not public.gs_app_release_verified(new.request_payload->'checks') then
  raise exception 'Verified deployment and typed release checks required before publication';
 end if;
 select * into v_release from public.gs_app_releases where id=new.release_id;
 if not found or v_release.status <> 'published' or v_release.platform <> 'web' or v_release.channel <> 'stable' then
  raise exception 'Release notification requires an active published stable web release';
 end if;
 if (new.request_payload->>'action') is distinct from 'publish'
    or (new.request_payload->>'id') is distinct from new.release_id::text
    or (new.before_state->>'status') is distinct from 'ready'
    or (new.after_state->'release'->>'status') is distinct from 'published'
    or (new.after_state->'release'->>'id') is distinct from new.release_id::text then
  raise exception 'Publication event transition evidence does not match release';
 end if;
 return new;
end; $$;
revoke all on function public.gs_app_release_publish_gate() from public,anon,authenticated;
commit;
