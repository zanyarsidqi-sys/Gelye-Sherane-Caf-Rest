-- Apply only to isolated staging after 1494. No automatic production migration.
begin;
-- Require JSON booleans (not string lookalikes) for every verification check.
create or replace function public.gs_app_release_verified(p_checks jsonb)
returns boolean language sql immutable set search_path='' as $$
 select jsonb_typeof(p_checks)='object'
    and (p_checks->'deployment_verified') = 'true'::jsonb
    and (p_checks->'smoke') = 'true'::jsonb
    and (p_checks->'permissions') = 'true'::jsonb
    and (p_checks->'backend') = 'true'::jsonb
    and (p_checks->'backup') = 'true'::jsonb
    and (p_checks->'artifact') = 'true'::jsonb;
$$;
revoke all on function public.gs_app_release_verified(jsonb) from public,anon;
-- Prevent a publish event from being recorded for an unrelated/unpublished release.
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
    or (new.request_payload->>'id') is distinct from new.release_id::text then
  raise exception 'Publication event payload does not match release';
 end if;
 return new;
end; $$;
revoke all on function public.gs_app_release_publish_gate() from public,anon,authenticated;
commit;
