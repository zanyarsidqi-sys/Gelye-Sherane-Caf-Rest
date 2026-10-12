-- Upgrade 226: authenticated POS device heartbeats and conservative online status.
-- A device must be bound by a manager to a signed-in employee account.
-- Manual heartbeat test is available in Flutter; periodic device agent is not yet built.
alter table public.gs_cafe_pos_devices
 add column if not exists bound_employee_id uuid references auth.users(id);
create index if not exists gs_cafe_pos_devices_bound_employee_idx
 on public.gs_cafe_pos_devices(bound_employee_id) where enabled;

create or replace function public.gs_bind_cafe_pos_device_employee(
 p_device_id bigint, p_employee_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_device_id is null or p_employee_id is null or not exists (
  select 1 from auth.users u where u.id=p_employee_id
 ) then raise exception 'Invalid POS device or employee account'; end if;
 update public.gs_cafe_pos_devices
 set bound_employee_id=p_employee_id,last_seen_at=null
 where id=p_device_id;
 if not found then raise exception 'POS device not found'; end if;
end; $$;

create or replace function public.gs_cafe_pos_heartbeat_for_current_employee()
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Authenticated table access required';
 end if;
 update public.gs_cafe_pos_devices set last_seen_at=now()
 where bound_employee_id=auth.uid() and enabled=true;
 get diagnostics v_count = row_count;
 return v_count;
end; $$;

-- Keep existing result fields while adding derived status.
-- Status means last authenticated heartbeat, not print hardware readiness.
drop function if exists public.gs_list_cafe_pos_devices();
create function public.gs_list_cafe_pos_devices()
returns table(id bigint,name text,device_model text,department text,
 enabled boolean,last_seen_at timestamptz,connection_status text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query select d.id,d.name,d.device_model,d.department,d.enabled,d.last_seen_at,
 case when not d.enabled then 'Disabled'
      when d.last_seen_at is null then 'Never connected'
      when d.last_seen_at >= now()-interval '2 minutes' then 'Online (heartbeat)'
      else 'Offline / stale' end::text
 from public.gs_cafe_pos_devices d order by d.department,d.name;
end; $$;
revoke all on function public.gs_bind_cafe_pos_device_employee(bigint,uuid) from public,anon;
revoke all on function public.gs_cafe_pos_heartbeat_for_current_employee() from public,anon;
revoke all on function public.gs_list_cafe_pos_devices() from public,anon;
grant execute on function public.gs_bind_cafe_pos_device_employee(bigint,uuid) to authenticated;
grant execute on function public.gs_cafe_pos_heartbeat_for_current_employee() to authenticated;
grant execute on function public.gs_list_cafe_pos_devices() to authenticated;
