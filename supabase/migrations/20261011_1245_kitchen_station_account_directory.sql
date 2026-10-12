-- Upgrade 1245: expose enabled preparation stations for first-time account provisioning.
-- Never return password hashes or session tokens. Authorization matches account write RPC.
create or replace function public.gs_1245_kitchen_station_account_setup_directory()
returns table(station_key text,station_name text,username text,enabled boolean,
 order_print boolean,bill_print boolean,online boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
   or not exists(select 1 from public.gs_cafe_station_supervisors x
     where x.employee_id=auth.uid() and x.active) then
   raise exception 'Kitchen station supervisor required';
 end if;
 return query select s.station_key,s.display_name,a.username,s.enabled,
   coalesce(a.allow_order_print,false),coalesce(a.allow_bill_print,false),
   coalesce(exists(select 1 from public.gs_cafe_station_device_sessions d
     where d.station_key=s.station_key and d.revoked_at is null
       and d.expires_at>now() and d.last_seen_at>now()-interval '90 seconds'),false)
 from public.gs_cafe_preparation_stations s
 left join public.gs_cafe_station_accounts a on a.station_key=s.station_key
 order by s.display_name;
end $$;
revoke all on function public.gs_1245_kitchen_station_account_setup_directory() from public,anon;
grant execute on function public.gs_1245_kitchen_station_account_setup_directory() to authenticated;
