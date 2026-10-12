-- Apply to isolated staging only after 1496. Does not deploy or send notifications.
-- Bind publish-time review evidence to the checks approved at the ready transition.
begin;
create or replace function public.gs_app_release_publish_gate() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_release public.gs_app_releases; v_key text;
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
    or (new.after_state->'release'->>'id') is distinct from new.release_id::text
    or (new.before_state->>'id') is distinct from new.release_id::text
    or (new.after_state->'release'->>'version') is distinct from v_release.version then
  raise exception 'Publication transition evidence does not match release';
 end if;
 -- Do not permit the publisher to replace an earlier failed review with unchecked
 -- publish-time booleans. The deployment_verified flag is intentionally new.
 foreach v_key in array array['smoke','permissions','backend','backup','artifact'] loop
  if (v_release.checks->v_key) is distinct from 'true'::jsonb
     or (new.request_payload->'checks'->v_key) is distinct from (v_release.checks->v_key) then
   raise exception 'Publication checks must match approved release review';
  end if;
 end loop;
 return new;
end; $$;
revoke all on function public.gs_app_release_publish_gate() from public,anon,authenticated;
commit;
