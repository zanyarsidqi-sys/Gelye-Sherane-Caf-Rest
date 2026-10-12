-- Upgrade 1242: owner/supervisor-controlled creation of a station with an existing
-- configured printing target. No placeholder stations without a target.
create or replace function public.gs_1242_create_station(
 p_key text, p_name text, p_method text, p_target_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare v_name text := btrim(coalesce(p_name,''));
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
    or not public.gs_can_access('kitchen','can_edit')
    or not exists (select 1 from public.gs_cafe_station_supervisors s
                   where s.employee_id=auth.uid() and s.active) then
   raise exception 'MFA and kitchen supervisor permission required';
 end if;
 if p_key is null or p_key !~ '^[a-z][a-z0-9_]{1,39}$'
    or char_length(v_name) not between 1 and 100
    or p_method is null or p_method not in ('pos','printer')
    or p_target_id is null or p_target_id <= 0 then
   raise exception 'Invalid station details';
 end if;
 if p_method='printer' and not exists(
    select 1 from public.gs_cafe_printers p
    where p.id=p_target_id and p.is_enabled) then
   raise exception 'An enabled printer must be configured first';
 end if;
 if p_method='pos' and not exists(
    select 1 from public.gs_cafe_pos_devices d where d.id=p_target_id) then
   raise exception 'An existing POS device must be configured first';
 end if;
 insert into public.gs_cafe_preparation_stations(
   station_key,display_name,enabled,online_method,pos_device_id,printer_id,updated_by)
 values (p_key,v_name,true,p_method,
   case when p_method='pos' then p_target_id else null end,
   case when p_method='printer' then p_target_id else null end,
   auth.uid());
end $$;
revoke all on function public.gs_1242_create_station(text,text,text,bigint) from public,anon;
grant execute on function public.gs_1242_create_station(text,text,text,bigint) to authenticated;
