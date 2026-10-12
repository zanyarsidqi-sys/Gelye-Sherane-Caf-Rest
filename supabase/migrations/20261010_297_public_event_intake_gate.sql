-- Upgrade 297: secure public submission gate and durable rate-limit counters.
create table if not exists public.gs_public_event_rate_limits (
 key_hash text primary key, window_started timestamptz not null default now(),
 attempts integer not null default 0
);
alter table public.gs_public_event_rate_limits enable row level security;
revoke all on public.gs_public_event_rate_limits from public,anon,authenticated;
create or replace function public.gs_public_event_rate_limit(p_key_hash text)
returns boolean language plpgsql security definer set search_path='' as $$
declare n int;
begin
 if auth.role()<>'service_role' then raise exception 'Not authorized' using errcode='42501'; end if;
 if p_key_hash !~ '^[a-f0-9]{64}$' then raise exception 'Invalid key'; end if;
 insert into public.gs_public_event_rate_limits(key_hash,attempts)
 values(p_key_hash,1)
 on conflict(key_hash) do update set
  window_started=case when public.gs_public_event_rate_limits.window_started<now()-interval '1 hour'
    then now() else public.gs_public_event_rate_limits.window_started end,
  attempts=case when public.gs_public_event_rate_limits.window_started<now()-interval '1 hour'
    then 1 else public.gs_public_event_rate_limits.attempts+1 end
 returning attempts into n;
 return n<=5;
end $$;
revoke all on function public.gs_public_event_rate_limit(text) from public,anon,authenticated;
grant execute on function public.gs_public_event_rate_limit(text) to service_role;
-- No public event write RPC is exposed yet. Never reuse staff-only functions
-- through a service-role endpoint without a separate, fully validated intake RPC.
