-- Upgrade 310: align customer QR assistance options with database validation.
-- Existing installations may still have the original five-type CHECK constraint.
do $$
declare v_constraint record;
begin
 for v_constraint in
  select c.conname from pg_constraint c
  where c.conrelid='public.gs_customer_staff_calls'::regclass
    and c.contype='c' and pg_get_constraintdef(c.oid) like '%call_type%'
 loop
  execute format('alter table public.gs_customer_staff_calls drop constraint %I',v_constraint.conname);
 end loop;
end $$;
alter table public.gs_customer_staff_calls
 add constraint gs_customer_staff_calls_type_check
 check (call_type in ('waiter','cashier','shisha','supervisor','any',
  'specific_order','extra_chairs','long_wait','pick_dishes','clean_table'));

-- Replace original request RPC so new types can actually be submitted.
create or replace function public.gs_customer_request_employee(
 p_session_token uuid,p_call_type text,p_note text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.gs_customer_visit_sessions%rowtype; v_id uuid;
begin
 if p_session_token is null then raise exception 'Visit authorization required'; end if;
 select x.* into s from public.gs_customer_visit_sessions x
 join public.gs_cafe_tables t on t.id=x.table_id
 join public.gs_table_visits v on v.id=x.visit_id and v.table_id=x.table_id
 where x.session_token=p_session_token and x.revoked_at is null and x.expires_at>now()
 and t.occupied=true and v.status='open' for update of x;
 if not found then raise exception 'Visit authorization required'; end if;
 if p_call_type is null or p_call_type not in
 ('waiter','cashier','shisha','supervisor','any','specific_order',
 'extra_chairs','long_wait','pick_dishes','clean_table')
 or length(coalesce(p_note,''))>300 then raise exception 'Invalid assistance request'; end if;
 if p_call_type='specific_order' and length(trim(coalesce(p_note,'')))<2 then
  raise exception 'Specific order description is required'; end if;
 if p_call_type='extra_chairs' and
  (coalesce(p_note,'') !~ '^Extra chairs requested: (10|[1-9])([.]|$)') then
  raise exception 'Invalid chair quantity'; end if;
 if exists(select 1 from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.table_id=s.table_id and c.status in ('waiting','accepted','on_way')) then
  raise exception 'An assistance request is already active'; end if;
 if (select count(*) from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.requested_at>now()-interval '1 hour')>=5 then
  raise exception 'Too many requests for this visit'; end if;
 insert into public.gs_customer_staff_calls(table_id,visit_id,call_type,note)
 values(s.table_id,s.visit_id,p_call_type,trim(coalesce(p_note,''))) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_customer_request_employee(uuid,text,text) from public;
grant execute on function public.gs_customer_request_employee(uuid,text,text) to anon,authenticated;
