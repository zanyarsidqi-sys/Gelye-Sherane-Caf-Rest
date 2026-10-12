-- Staff-managed scheduled meal requests. QR room identification alone never authorizes guest orders.
create table if not exists public.gs_motel_scheduled_meals (
 id uuid primary key default extensions.gen_random_uuid(),
 room_id uuid not null references public.gs_motel_room_qr(id),
 meal_description text not null check (length(trim(meal_description)) between 3 and 500),
 requested_for timestamptz not null,
 status text not null default 'requested' check (status in ('requested','confirmed','scheduled','preparing','ready','on_way','delivered','cancelled','rejected')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.gs_motel_scheduled_meals enable row level security;
revoke all on public.gs_motel_scheduled_meals from public, anon, authenticated;
create or replace function public.gs_staff_schedule_motel_meal(p_room_label text,p_description text,p_requested_for timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_room uuid; v_id uuid;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_edit') then raise exception 'Permission denied'; end if;
 if length(trim(coalesce(p_description,''))) not between 3 and 500 then raise exception 'Meal description must be 3-500 characters'; end if;
 if p_requested_for is null or p_requested_for <= now() + interval '15 minutes' or p_requested_for > now() + interval '90 days' then raise exception 'Choose a delivery time 15 minutes to 90 days ahead'; end if;
 select id into v_room from public.gs_motel_room_qr where room_label=trim(p_room_label) and is_active;
 if v_room is null then raise exception 'Active room not found'; end if;
 insert into public.gs_motel_scheduled_meals(room_id,meal_description,requested_for,created_by)
 values(v_room,trim(p_description),p_requested_for,auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_staff_schedule_motel_meal(text,text,timestamptz) from public,anon;
grant execute on function public.gs_staff_schedule_motel_meal(text,text,timestamptz) to authenticated;
create or replace function public.gs_staff_list_motel_scheduled_meals()
returns table(id uuid,room_label text,room_name text,meal_description text,requested_for timestamptz,status text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_view') then raise exception 'Permission denied'; end if;
 return query select m.id,r.room_label,r.room_name,m.meal_description,m.requested_for,m.status
 from public.gs_motel_scheduled_meals m join public.gs_motel_room_qr r on r.id=m.room_id
 order by m.requested_for desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_scheduled_meals() from public,anon;
grant execute on function public.gs_staff_list_motel_scheduled_meals() to authenticated;
-- No anonymous create/list permission: guest QR ordering requires future stay-verification integration.
