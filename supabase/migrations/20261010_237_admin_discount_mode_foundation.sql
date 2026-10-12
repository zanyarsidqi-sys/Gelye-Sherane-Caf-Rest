-- Upgrade 237: Admin-controlled discount configuration (foundation only).
-- This migration does NOT change checkout prices or enable printing discounts.
-- Provision admin UUIDs only from a trusted service-role migration/admin console.
create table if not exists public.gs_cafe_discount_admins (
 user_id uuid primary key references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_cafe_discount_admins enable row level security;
revoke all on public.gs_cafe_discount_admins from public, anon, authenticated;

create table if not exists public.gs_cafe_discount_modes (
 id bigint generated always as identity primary key,
 scope text not null check (scope in ('table','motel')),
 scope_reference text not null check(length(trim(scope_reference)) between 1 and 120),
 is_active boolean not null default false,
 discount_type text not null check(discount_type in ('percent','fixed_iqd')),
 discount_value numeric(12,2) not null check(discount_value >= 0),
 base_mode text not null check(base_mode in ('normal','tourism','owner')),
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 unique(scope,scope_reference),
 constraint gs_discount_value_valid check (
  (discount_type='percent' and discount_value <= 100) or
  (discount_type='fixed_iqd' and discount_value = trunc(discount_value) and discount_value <= 1000000000)
 )
);
alter table public.gs_cafe_discount_modes enable row level security;
revoke all on public.gs_cafe_discount_modes from public,anon,authenticated;

create table if not exists public.gs_cafe_discount_mode_audit (
 id bigint generated always as identity primary key,
 discount_mode_id bigint not null references public.gs_cafe_discount_modes(id),
 actor_id uuid not null references auth.users(id),
 old_config jsonb,
 new_config jsonb not null,
 changed_at timestamptz not null default now()
);
alter table public.gs_cafe_discount_mode_audit enable row level security;
revoke all on public.gs_cafe_discount_mode_audit from public,anon,authenticated;

create or replace function public.gs_set_cafe_discount_mode(
 p_scope text,p_scope_reference text,p_is_active boolean,
 p_discount_type text,p_discount_value numeric,p_base_mode text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_id bigint; v_old jsonb; v_new jsonb;
begin
 if v_uid is null or not exists(select 1 from public.gs_cafe_discount_admins where user_id=v_uid)
 then raise exception 'Admin authorization required'; end if;
 if p_scope not in ('table','motel') or p_scope_reference is null
    or length(trim(p_scope_reference)) not between 1 and 120
    or p_is_active is null or p_discount_type not in ('percent','fixed_iqd')
    or p_base_mode not in ('normal','tourism','owner')
    or p_discount_value is null or p_discount_value < 0
    or (p_discount_type='percent' and p_discount_value>100)
    or (p_discount_type='fixed_iqd' and
       (p_discount_value<>trunc(p_discount_value) or p_discount_value>1000000000))
 then raise exception 'Invalid discount configuration'; end if;
 select id,to_jsonb(d) into v_id,v_old from public.gs_cafe_discount_modes d
 where scope=p_scope and scope_reference=trim(p_scope_reference) for update;
 insert into public.gs_cafe_discount_modes
 (scope,scope_reference,is_active,discount_type,discount_value,base_mode,updated_by)
 values(p_scope,trim(p_scope_reference),p_is_active,p_discount_type,p_discount_value,p_base_mode,v_uid)
 on conflict(scope,scope_reference) do update set
 is_active=excluded.is_active,discount_type=excluded.discount_type,
 discount_value=excluded.discount_value,base_mode=excluded.base_mode,
 updated_by=excluded.updated_by,updated_at=now()
 returning id into v_id;
 select to_jsonb(d) into v_new from public.gs_cafe_discount_modes d where id=v_id;
 insert into public.gs_cafe_discount_mode_audit(discount_mode_id,actor_id,old_config,new_config)
 values(v_id,v_uid,v_old,v_new);
 return v_id;
end; $$;
revoke all on function public.gs_set_cafe_discount_mode(text,text,boolean,text,numeric,text) from public,anon;
grant execute on function public.gs_set_cafe_discount_mode(text,text,boolean,text,numeric,text) to authenticated;

create or replace function public.gs_list_cafe_discount_modes()
returns table(scope text,scope_reference text,is_active boolean,discount_type text,
 discount_value numeric,base_mode text,updated_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 return query select d.scope,d.scope_reference,d.is_active,d.discount_type,
 d.discount_value,d.base_mode,d.updated_at from public.gs_cafe_discount_modes d
 order by d.updated_at desc limit 500;
end; $$;
revoke all on function public.gs_list_cafe_discount_modes() from public,anon;
grant execute on function public.gs_list_cafe_discount_modes() to authenticated;
