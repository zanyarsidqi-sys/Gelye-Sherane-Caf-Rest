-- Upgrade 1226: server-side station POS logout. Token never stored in plaintext.
create or replace function public.gs_1226_device_logout(p_token_hash text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 if p_token_hash !~ '^[0-9a-f]{64}$' then return false; end if;
 update public.gs_cafe_station_device_sessions
 set revoked_at=now()
 where token_hash=p_token_hash and revoked_at is null;
 get diagnostics v_count=row_count;
 -- Idempotent: already-revoked/expired sessions may still be safely cleared.
 return v_count>0 or exists(select 1 from public.gs_cafe_station_device_sessions
   where token_hash=p_token_hash and revoked_at is not null);
end $$;
revoke all on function public.gs_1226_device_logout(text) from public,anon,authenticated;
grant execute on function public.gs_1226_device_logout(text) to service_role;
