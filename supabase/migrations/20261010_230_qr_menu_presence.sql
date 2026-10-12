-- Upgrade 230: anonymous short-lived QR menu presence, not table occupancy.
create table if not exists public.gs_table_qr_menu_sessions (
  table_id bigint not null references public.gs_cafe_tables(id) on delete cascade,
  session_key text not null check(length(session_key) between 16 and 64),
  last_seen_at timestamptz not null default now(),
  primary key(table_id,session_key)
);
create index if not exists gs_table_qr_menu_sessions_seen_idx
  on public.gs_table_qr_menu_sessions(last_seen_at);
alter table public.gs_table_qr_menu_sessions enable row level security;
revoke all on public.gs_table_qr_menu_sessions from public,anon,authenticated;

create or replace function public.gs_touch_public_table_qr_session(
  p_token uuid,p_session_key text) returns void
language plpgsql security definer set search_path='' as $$
declare v_table_id bigint;
begin
  if p_session_key is null or p_session_key !~ '^[0-9a-f]{32}$' then
    raise exception 'Invalid anonymous session key';
  end if;
  select table_id into v_table_id from public.gs_table_qr_tokens
    where token=p_token;
  if v_table_id is null then raise exception 'Invalid table QR code'; end if;
  insert into public.gs_table_qr_menu_sessions(table_id,session_key,last_seen_at)
    values(v_table_id,p_session_key,now())
  on conflict(table_id,session_key) do update set last_seen_at=now();
end; $$;
revoke all on function public.gs_touch_public_table_qr_session(uuid,text) from public;
grant execute on function public.gs_touch_public_table_qr_session(uuid,text) to anon,authenticated;

create or replace function public.gs_list_active_table_qr_sessions()
returns table(table_number integer,active_sessions bigint,last_seen_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.gs_can_access('tables','can_view') then
    raise exception 'Tables viewing permission denied';
  end if;
  return query
    select t.table_number,count(*)::bigint,max(s.last_seen_at)
    from public.gs_table_qr_menu_sessions s
    join public.gs_cafe_tables t on t.id=s.table_id
    where s.last_seen_at > now()-interval '2 minutes'
    group by t.table_number;
end; $$;
revoke all on function public.gs_list_active_table_qr_sessions() from public,anon;
grant execute on function public.gs_list_active_table_qr_sessions() to authenticated;
-- Note: public endpoint should have edge/WAF rate limiting in production.
-- No names, IPs, permanent device identifiers, or order information stored.
