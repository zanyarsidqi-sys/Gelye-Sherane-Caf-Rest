-- Upgrade 228: scoped POS heartbeats. This is employee/device selection,
-- NOT cryptographic hardware attestation. No secret device_key is returned.
-- Remove the previous account-wide heartbeat permission to prevent a single
-- employee session making every bound device appear online.
revoke all on function public.gs_cafe_pos_heartbeat_for_current_employee() from public, anon, authenticated;

create or replace function public.gs_my_bound_cafe_pos_devices()
returns table(id bigint, name text, device_model text, department text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Authenticated table access required';
 end if;
 return query select d.id,d.name,d.device_model,d.department
 from public.gs_cafe_pos_devices d
 where d.bound_employee_id=auth.uid() and d.enabled=true
 order by d.department,d.name;
end; $$;

create or replace function public.gs_cafe_pos_heartbeat_for_device(p_device_id bigint)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Authenticated table access required';
 end if;
 if p_device_id is null then raise exception 'Device must be selected'; end if;
 update public.gs_cafe_pos_devices d set last_seen_at=now()
 where d.id=p_device_id and d.bound_employee_id=auth.uid() and d.enabled=true;
 if not found then raise exception 'Device not enabled or not bound to this employee'; end if;
 return true;
end; $$;
revoke all on function public.gs_my_bound_cafe_pos_devices() from public,anon;
revoke all on function public.gs_cafe_pos_heartbeat_for_device(bigint) from public,anon;
grant execute on function public.gs_my_bound_cafe_pos_devices() to authenticated;
grant execute on function public.gs_cafe_pos_heartbeat_for_device(bigint) to authenticated;
