create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  created_at timestamptz not null default now()
);

alter table public.staff_profiles enable row level security;

revoke all on public.staff_profiles from anon, authenticated;
grant select on public.staff_profiles to authenticated;

create or replace function public.is_staff_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff_profiles
    where user_id = (select auth.uid())
      and role = 'admin'
  );
$$;

revoke all on function public.is_staff_admin() from public, anon;
grant execute on function public.is_staff_admin() to authenticated;

drop policy if exists "Staff can read their own profile and admins can read all"
on public.staff_profiles;

create policy "Staff can read their own profile and admins can read all"
on public.staff_profiles
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_staff_admin())
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.staff_profiles (user_id, email, role)
  values (new.id, new.email, 'staff')
  on conflict (user_id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_auth_user();
