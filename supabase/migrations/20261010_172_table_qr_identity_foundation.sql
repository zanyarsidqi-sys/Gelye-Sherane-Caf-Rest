-- Upgrade 172: revocable per-table QR identity (foundation, not public ordering).
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.gs_table_qr_tokens(
 table_id bigint primary key references public.gs_cafe_tables(id) on delete cascade,
 token uuid not null unique default extensions.gen_random_uuid(),
 issued_at timestamptz not null default now(),
 issued_by uuid not null references auth.users(id),
 rotation_count integer not null default 0 check(rotation_count>=0)
);
alter table public.gs_table_qr_tokens enable row level security;
revoke all on public.gs_table_qr_tokens from public,anon,authenticated;

create or replace function public.gs_get_table_qr(p_table_number integer)
returns table(table_number integer,qr_token uuid,issued_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'QR management permission denied';
 end if;
 select t.id into v_id from public.gs_cafe_tables t
 where t.table_number=p_table_number for update;
 if not found then raise exception 'Table not found'; end if;
 insert into public.gs_table_qr_tokens(table_id,issued_by)
 values(v_id,auth.uid()) on conflict(table_id) do nothing;
 return query select t.table_number,q.token,q.issued_at
 from public.gs_table_qr_tokens q join public.gs_cafe_tables t on t.id=q.table_id
 where t.id=v_id;
end; $$;

create or replace function public.gs_rotate_table_qr(p_table_number integer)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_token uuid;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'QR rotation permission denied';
 end if;
 perform 1 from public.gs_cafe_tables t
 where t.table_number=p_table_number for update;
 if not found then raise exception 'Table not found'; end if;
 insert into public.gs_table_qr_tokens(table_id,token,issued_by)
 select t.id,extensions.gen_random_uuid(),auth.uid()
 from public.gs_cafe_tables t where t.table_number=p_table_number
 on conflict(table_id) do update set
  token=extensions.gen_random_uuid(),issued_at=now(),issued_by=auth.uid(),
  rotation_count=public.gs_table_qr_tokens.rotation_count+1
 returning token into v_token;
 return v_token;
end; $$;

-- Public scanner lookup exposes ONLY a table identifier, never occupancy,
-- customer details, pricing mode, orders, reservation or internal IDs.
create or replace function public.gs_resolve_table_qr(p_token uuid)
returns table(table_number integer)
language sql stable security definer set search_path='' as $$
 select t.table_number from public.gs_table_qr_tokens q
 join public.gs_cafe_tables t on t.id=q.table_id
 where q.token=p_token
 limit 1;
$$;
revoke all on function public.gs_get_table_qr(integer) from public,anon;
revoke all on function public.gs_rotate_table_qr(integer) from public,anon;
revoke all on function public.gs_resolve_table_qr(uuid) from public;
grant execute on function public.gs_get_table_qr(integer) to authenticated;
grant execute on function public.gs_rotate_table_qr(integer) to authenticated;
grant execute on function public.gs_resolve_table_qr(uuid) to anon,authenticated;
