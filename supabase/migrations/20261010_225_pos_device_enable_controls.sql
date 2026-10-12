-- Upgrade 225: authenticated manager-only POS enable/disable control.
-- Registration is provided by gs_register_cafe_pos_device from Upgrade 224.
create or replace function public.gs_set_cafe_pos_device_enabled(p_device_id bigint,p_enabled boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Table manager permission required';
 end if;
 if p_device_id is null or p_enabled is null then
   raise exception 'Device ID and enabled status required';
 end if;
 update public.gs_cafe_pos_devices set enabled=p_enabled where id=p_device_id;
 if not found then raise exception 'POS device not found'; end if;
end; $$;
revoke all on function public.gs_set_cafe_pos_device_enabled(bigint,boolean) from public,anon;
grant execute on function public.gs_set_cafe_pos_device_enabled(bigint,boolean) to authenticated;
