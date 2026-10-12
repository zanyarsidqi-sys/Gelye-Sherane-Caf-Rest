-- Upgrade 276: visit-bound customer capability sessions (foundation).
-- Staff issuance only. A static table QR is NOT an authorization credential.
create table if not exists public.gs_customer_visit_sessions (
  session_token uuid primary key default gen_random_uuid(),
  table_id bigint not null references public.gs_cafe_tables(id),
  visit_id bigint not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 hours'),
  revoked_at timestamptz,
  issued_by uuid not null,
  constraint gs_visit_session_valid_expiry check (expires_at > created_at)
);
create index if not exists gs_customer_visit_sessions_table_active_idx
  on public.gs_customer_visit_sessions(table_id, expires_at) where revoked_at is null;
alter table public.gs_customer_visit_sessions enable row level security;
revoke all on public.gs_customer_visit_sessions from public, anon, authenticated;

-- This is a staff-operated foundation. Public self-service QR exchange
-- requires additional abuse protection and current-visit proof.
create or replace function public.gs_staff_issue_customer_visit_session(
  p_table_id bigint, p_visit_id bigint)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_token uuid;
begin
  if auth.uid() is null or not public.gs_can_access('tables','can_view') then
    raise exception 'Not authorized';
  end if;
  if not exists(select 1 from public.gs_cafe_tables t
                where t.id=p_table_id and t.occupied=true) then
    raise exception 'Table is not occupied';
  end if;
  if not exists(select 1 from public.gs_table_visits v
                where v.id=p_visit_id and v.table_id=p_table_id
                  and v.status='open') then
    raise exception 'No matching open visit';
  end if;
  insert into public.gs_customer_visit_sessions(table_id,visit_id,issued_by)
    values(p_table_id,p_visit_id,auth.uid()) returning session_token into v_token;
  return v_token;
end $$;
revoke all on function public.gs_staff_issue_customer_visit_session(bigint,bigint) from public,anon;
grant execute on function public.gs_staff_issue_customer_visit_session(bigint,bigint) to authenticated;

create or replace function public.gs_customer_visit_session_valid(p_token uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists (
   select 1 from public.gs_customer_visit_sessions s
   join public.gs_cafe_tables t on t.id=s.table_id
   join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id
   where s.session_token=p_token and s.revoked_at is null
     and s.expires_at>now() and t.occupied=true and v.status='open'
 );
$$;
revoke all on function public.gs_customer_visit_session_valid(uuid) from public;
grant execute on function public.gs_customer_visit_session_valid(uuid) to anon,authenticated;

create or replace function public.gs_revoke_customer_sessions_on_table_release()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.occupied=true and new.occupied=false then
    update public.gs_customer_visit_sessions s set revoked_at=now()
    where s.table_id=old.id and s.revoked_at is null;
  end if;
  return new;
end $$;
revoke all on function public.gs_revoke_customer_sessions_on_table_release() from public,anon,authenticated;
drop trigger if exists gs_customer_sessions_checkout_revoke on public.gs_cafe_tables;
create trigger gs_customer_sessions_checkout_revoke
 after update of occupied on public.gs_cafe_tables
 for each row execute function public.gs_revoke_customer_sessions_on_table_release();
