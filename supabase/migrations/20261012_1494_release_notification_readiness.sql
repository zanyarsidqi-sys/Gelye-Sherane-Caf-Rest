-- STAGING ONLY: Apply after 1493 and browser_push.sql. No production changes.
begin;
-- Publishing requires explicit deployment verification in the publish request;
-- merely marking a draft ready must not generate an announcement.
create or replace function public.gs_app_release_verified(p_checks jsonb)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_checks->>'deployment_verified','')='true'
   and coalesce(p_checks->>'smoke','')='true'
   and coalesce(p_checks->>'permissions','')='true'
   and coalesce(p_checks->>'backend','')='true'
   and coalesce(p_checks->>'backup','')='true'
   and coalesce(p_checks->>'artifact','')='true';
$$;
revoke all on function public.gs_app_release_verified(jsonb) from public,anon;
-- Use a separate audited gate at the release event insertion boundary. This
-- is in the same transaction as publication; rejection rolls back publication.
create function public.gs_app_release_publish_gate() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.action='publish' and not public.gs_app_release_verified(new.request_payload->'checks') then
  raise exception 'Deployment verification and release checks required before publication notification';
 end if;
 return new;
end; $$;
revoke all on function public.gs_app_release_publish_gate() from public,anon,authenticated;
create trigger gs_release_publish_verification_gate
 before insert on public.gs_app_release_events
 for each row execute function public.gs_app_release_publish_gate();
-- Employee-only, MFA-protected published release history for the Notifications UI.
create function public.gs_my_published_release_history(p_limit integer default 10)
returns table(version text, notes text, published_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
  or not exists(select 1 from public.employee_profiles e where e.user_id=auth.uid() and e.is_active)
  or not public.gs_can_access('notifications','can_view')
 then raise exception 'Active authorized MFA employee required' using errcode='42501'; end if;
 if p_limit is null or p_limit<1 or p_limit>30 then raise exception 'Invalid history limit'; end if;
 return query select r.version::text,r.notes::text,e.created_at
 from public.gs_app_release_events e
 join public.gs_app_releases r on r.id=e.release_id
 where e.action='publish' and r.platform='web' and r.channel='stable'
 order by e.created_at desc,e.id desc limit p_limit;
end; $$;
revoke all on function public.gs_my_published_release_history(integer) from public,anon;
grant execute on function public.gs_my_published_release_history(integer) to authenticated;
commit;
