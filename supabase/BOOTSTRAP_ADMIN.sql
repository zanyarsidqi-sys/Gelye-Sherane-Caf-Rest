do $$
declare
  admin_user auth.users%rowtype;
begin
  select *
  into admin_user
  from auth.users
  where lower(email) = lower('REPLACE_WITH_YOUR_SUPABASE_EMAIL')
  limit 1;

  if admin_user.id is null then
    raise exception 'No Supabase Auth user found for the supplied email.';
  end if;

  insert into public.staff_profiles (user_id, email, role)
  values (admin_user.id, admin_user.email, 'admin')
  on conflict (user_id) do update
    set email = excluded.email,
        role = 'admin';
end;
$$;
