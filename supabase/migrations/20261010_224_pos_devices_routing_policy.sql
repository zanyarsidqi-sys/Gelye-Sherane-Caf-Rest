-- Upgrade 224: POS device registry and online/offline routing POLICY only.
-- No direct SUNMI SDK integration, offline queue, print gateway, or physical printing.
create table if not exists public.gs_cafe_pos_devices (
 id bigint generated always as identity primary key,
 name text not null check(length(trim(name)) between 1 and 120),
 device_model text not null default 'sunmi_v2',
 department text not null default 'general',
 device_key text not null unique check(length(trim(device_key)) between 1 and 120),
 enabled boolean not null default true,
 last_seen_at timestamptz,
 created_at timestamptz not null default now(),
 constraint gs_pos_model_nonempty check(length(trim(device_model)) > 0)
);
create table if not exists public.gs_cafe_print_routing_policy (
 department text primary key check(length(trim(department)) between 1 and 80),
 online_route text not null default 'both' check(online_route in ('pos','printer','both')),
 offline_route text not null default 'local_printer' check(offline_route = 'local_printer'),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
alter table public.gs_cafe_pos_devices enable row level security;
alter table public.gs_cafe_print_routing_policy enable row level security;
revoke all on public.gs_cafe_pos_devices from public,anon,authenticated;
revoke all on public.gs_cafe_print_routing_policy from public,anon,authenticated;
create or replace function public.gs_list_cafe_pos_devices()
returns table(id bigint,name text,device_model text,department text,enabled boolean,last_seen_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query select d.id,d.name,d.device_model,d.department,d.enabled,d.last_seen_at
 from public.gs_cafe_pos_devices d order by d.department,d.name;
end; $$;
create or replace function public.gs_register_cafe_pos_device(
 p_name text,p_device_model text,p_department text,p_device_key text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_name is null or length(trim(p_name)) not between 1 and 120 or
    p_device_model is null or length(trim(p_device_model)) not between 1 and 120 or
    p_department is null or length(trim(p_department)) not between 1 and 80 or
    p_device_key is null or length(trim(p_device_key)) not between 1 and 120 then
  raise exception 'Invalid device details';
 end if;
 insert into public.gs_cafe_pos_devices(name,device_model,department,device_key)
 values(trim(p_name),trim(p_device_model),trim(p_department),trim(p_device_key))
 returning id into v_id;
 return v_id;
end; $$;
create or replace function public.gs_list_cafe_print_routing_policy()
returns table(department text,online_route text,offline_route text,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Table view permission required';
 end if;
 return query select p.department,p.online_route,p.offline_route,p.updated_at
 from public.gs_cafe_print_routing_policy p order by p.department;
end; $$;
create or replace function public.gs_set_cafe_print_routing_policy(p_department text,p_online_route text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table manager permission required';
 end if;
 if p_department is null or length(trim(p_department)) not between 1 and 80 or
    p_online_route is null or p_online_route not in ('pos','printer','both') then
  raise exception 'Invalid routing policy';
 end if;
 insert into public.gs_cafe_print_routing_policy(department,online_route,offline_route,updated_by)
 values(trim(p_department),p_online_route,'local_printer',auth.uid())
 on conflict(department) do update set online_route=excluded.online_route,
 updated_by=excluded.updated_by,updated_at=now();
end; $$;
revoke all on function public.gs_list_cafe_pos_devices() from public,anon;
revoke all on function public.gs_register_cafe_pos_device(text,text,text,text) from public,anon;
revoke all on function public.gs_list_cafe_print_routing_policy() from public,anon;
revoke all on function public.gs_set_cafe_print_routing_policy(text,text) from public,anon;
grant execute on function public.gs_list_cafe_pos_devices() to authenticated;
grant execute on function public.gs_register_cafe_pos_device(text,text,text,text) to authenticated;
grant execute on function public.gs_list_cafe_print_routing_policy() to authenticated;
grant execute on function public.gs_set_cafe_print_routing_policy(text,text) to authenticated;
