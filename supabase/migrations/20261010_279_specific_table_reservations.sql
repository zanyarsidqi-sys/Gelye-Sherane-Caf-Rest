-- Upgrade 279: customer-selected and staff-created specific-table reservations.
-- Uses existing reservable table inventory and reservation requests.
-- Public requests are pending; only authorized staff may confirm them.
alter table public.gs_public_reservation_requests
 add column if not exists requested_table_id uuid references public.gs_reservable_tables(id),
 add column if not exists booking_source text not null default 'customer' check (booking_source in ('customer','staff')),
 add column if not exists created_by_employee uuid;

create or replace function public.gs_public_reservable_table_options(p_party_size integer)
returns table(table_id uuid, table_label text, seats integer)
language sql stable security definer set search_path='' as $$
 select t.id,t.table_label,t.seats from public.gs_reservable_tables t
 where t.enabled and t.seats >= p_party_size and p_party_size between 1 and 30
 order by t.seats,t.table_label limit 100;
$$;
revoke all on function public.gs_public_reservable_table_options(integer) from public;
grant execute on function public.gs_public_reservable_table_options(integer) to anon,authenticated;

-- Read-only availability hint; concurrent requests may still occur.
-- Confirmation is protected by the serialized staff booking function below.
create or replace function public.gs_public_table_available(
 p_table_id uuid,p_start timestamptz,p_duration integer,p_party_size integer)
returns boolean language sql stable security definer set search_path='' as $$
 select p_start>now() and p_start<=now()+interval '90 days'
 and p_duration between 30 and 360 and p_party_size between 1 and 30
 and exists(select 1 from public.gs_reservable_tables t
            where t.id=p_table_id and t.enabled and t.seats>=p_party_size)
 and not exists(select 1 from public.gs_public_reservation_requests r
 where r.status='approved' and r.assigned_table_id=p_table_id
 and r.requested_at < p_start + make_interval(mins=>p_duration)
 and r.requested_at + make_interval(mins=>r.duration_minutes) > p_start);
$$;
revoke all on function public.gs_public_table_available(uuid,timestamptz,integer,integer) from public;
grant execute on function public.gs_public_table_available(uuid,timestamptz,integer,integer) to anon,authenticated;

create or replace function public.gs_customer_request_specific_table(
 p_name text,p_phone text,p_table_id uuid,p_start timestamptz,
 p_party_size integer,p_duration integer default 120,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100
 or length(trim(coalesce(p_phone,''))) not between 6 and 30
 or p_start<=now() or p_start>now()+interval '90 days'
 or p_party_size not between 1 and 30 or p_duration not between 30 and 360
 or length(coalesce(p_notes,''))>500 then raise exception 'Invalid reservation request'; end if;
 if not public.gs_public_table_available(p_table_id,p_start,p_duration,p_party_size)
 then raise exception 'Requested table is not available'; end if;
 insert into public.gs_public_reservation_requests
 (customer_name,phone,requested_at,party_size,notes,requested_table_id,duration_minutes,booking_source)
 values(trim(p_name),trim(p_phone),p_start,p_party_size,nullif(trim(coalesce(p_notes,'')),''),p_table_id,p_duration,'customer')
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_customer_request_specific_table(text,text,uuid,timestamptz,integer,integer,text) from public;
grant execute on function public.gs_customer_request_specific_table(text,text,uuid,timestamptz,integer,integer,text) to anon,authenticated;
-- IMPORTANT: deploy edge CAPTCHA/rate-limiting before exposing anonymous RPC in production.

create or replace function public.gs_staff_book_specific_table(
 p_name text,p_phone text,p_table_id uuid,p_start timestamptz,
 p_party_size integer,p_duration integer default 120,p_notes text default null,
 p_existing_request_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_status text; v_requested uuid;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
   raise exception 'Not authorized to manage reservations'; end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 100
 or length(trim(coalesce(p_phone,''))) not between 6 and 30
 or p_start<=now() or p_start>now()+interval '90 days'
 or p_party_size not between 1 and 30 or p_duration not between 30 and 360
 or length(coalesce(p_notes,''))>500 then raise exception 'Invalid reservation'; end if;
 perform pg_advisory_xact_lock(721903,1);
 if p_existing_request_id is not null then
   select status,requested_table_id into v_status,v_requested
   from public.gs_public_reservation_requests where id=p_existing_request_id for update;
   if v_status is distinct from 'pending' or v_requested is distinct from p_table_id
   then raise exception 'Request is no longer pending or selected table changed'; end if;
 end if;
 if not public.gs_public_table_available(p_table_id,p_start,p_duration,p_party_size)
 then raise exception 'Selected table has a conflicting booking or insufficient capacity'; end if;
 if p_existing_request_id is null then
  insert into public.gs_public_reservation_requests
  (customer_name,phone,requested_at,party_size,notes,requested_table_id,
   assigned_table_id,duration_minutes,booking_source,created_by_employee,status)
  values(trim(p_name),trim(p_phone),p_start,p_party_size,nullif(trim(coalesce(p_notes,'')),''),
   p_table_id,p_table_id,p_duration,'staff',auth.uid(),'approved') returning id into v_id;
  insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
  values('reservation',v_id,'created','approved',auth.uid());
 else
  update public.gs_public_reservation_requests
  set status='approved',assigned_table_id=p_table_id,
      customer_name=trim(p_name),phone=trim(p_phone),requested_at=p_start,
      party_size=p_party_size,duration_minutes=p_duration,
      notes=nullif(trim(coalesce(p_notes,'')),'')
  where id=p_existing_request_id returning id into v_id;
  insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
  values('reservation',v_id,'pending','approved',auth.uid());
 end if;
 return v_id;
end $$;
revoke all on function public.gs_staff_book_specific_table(text,text,uuid,timestamptz,integer,integer,text,uuid) from public,anon;
grant execute on function public.gs_staff_book_specific_table(text,text,uuid,timestamptz,integer,integer,text,uuid) to authenticated;
