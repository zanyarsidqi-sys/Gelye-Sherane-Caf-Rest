-- Upgrade 1224: preserve failed attempts by returning no rows rather than raising.
-- An exception in a PostgreSQL function rolls back its INSERTs; the previous
-- login implementation therefore never persisted failed login attempts.
create or replace function public.gs_1223_device_login(p_username text,p_password text,p_token_hash text)
returns table(station_key text, session_id uuid, expires_at timestamptz,
 order_print boolean,bill_print boolean)
language plpgsql security definer set search_path='' as $$
declare a public.gs_cafe_station_accounts%rowtype;
 v_username text:=lower(btrim(coalesce(p_username,'')));
 v_session uuid; v_expires timestamptz:=now()+interval '30 days';
begin
 if current_user <> 'service_role' then raise exception 'Service access required'; end if;
 if length(v_username)>64 or length(coalesce(p_password,''))>128
  or p_token_hash !~ '^[0-9a-f]{64}$' then return; end if;
 -- Serialize attempts for each username to avoid concurrent bypasses.
 perform pg_advisory_xact_lock(hashtext(v_username));
 if (select count(*) from public.gs_cafe_station_login_attempts
     where username=v_username and attempt_at>now()-interval '15 minutes' and not success)>=5 then
   return;
 end if;
 select * into a from public.gs_cafe_station_accounts x
  where x.username=v_username and x.enabled;
 if not found or extensions.crypt(coalesce(p_password,''),a.password_hash)<>a.password_hash then
   insert into public.gs_cafe_station_login_attempts(username,success)
   values(v_username,false);
   return; -- no exception: persist the failed attempt
 end if;
 insert into public.gs_cafe_station_login_attempts(username,success)
 values(v_username,true);
 insert into public.gs_cafe_station_device_sessions(station_key,token_hash,credential_version,expires_at,last_seen_at)
 values(a.station_key,p_token_hash,a.credential_version,v_expires,now())
 returning id into v_session;
 return query select a.station_key,v_session,v_expires,a.allow_order_print,a.allow_bill_print;
end $$;
-- Server-side read only, no client access to attempts or password hashes.
revoke all on function public.gs_1223_device_login(text,text,text) from public,anon,authenticated;
grant execute on function public.gs_1223_device_login(text,text,text) to service_role;
