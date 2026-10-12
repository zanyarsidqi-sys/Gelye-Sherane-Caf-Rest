-- DRAFT: staff-created table service requests only. Public QR submission requires
-- separate authenticated guest session, rate limits, and anti-abuse protections.
create or replace function public.gs_create_table_service_task(
 p_table_id bigint, p_request_type text, p_quantity integer default 1,
 p_priority text default 'normal', p_notes text default null
) returns bigint
language plpgsql security definer set search_path = ''
as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
   raise exception 'Service request creation denied';
 end if;
 if p_table_id is null or p_table_id < 1 or not exists (
   select 1 from public.gs_cafe_tables where id=p_table_id
 ) then raise exception 'Unknown table'; end if;
 if p_request_type is null or p_request_type not in (
   'extra_tissues','fork','spoon','knife','extra_plate','extra_glass',
   'extra_chair','water_request','condiments','call_waiter','dish_pickup',
   'shisha_pickup','shisha_service','table_cleaning','other') then
   raise exception 'Invalid service request type';
 end if;
 if p_quantity is null or p_quantity not between 1 and 50 then
   raise exception 'Invalid quantity';
 end if;
 if p_priority is null or p_priority not in ('normal','urgent') then
   raise exception 'Invalid priority';
 end if;
 if length(coalesce(p_notes,'')) > 1000 then raise exception 'Notes too long'; end if;
 -- Per-user rate limit: maximum 10 created requests in the last minute.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,43));
 if (select count(*) from public.gs_table_service_tasks
     where created_by=auth.uid() and created_at > now()-interval '1 minute') >= 10 then
   raise exception 'Too many requests; please wait';
 end if;
 -- Prevent accidental duplicate active requests of same type for a table.
 if exists (select 1 from public.gs_table_service_tasks
    where table_id=p_table_id and request_type=p_request_type
      and status in ('pending','assigned','accepted','in_progress')
      and created_at > now()-interval '3 minutes') then
   raise exception 'Similar active request already exists';
 end if;
 insert into public.gs_table_service_tasks
   (table_id,request_type,quantity,priority,notes,created_by)
 values (p_table_id,p_request_type,p_quantity,p_priority,nullif(trim(p_notes),''),auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_create_table_service_task(bigint,text,integer,text,text)
 from public,anon;
grant execute on function public.gs_create_table_service_task(bigint,text,integer,text,text)
 to authenticated;
-- IMPORTANT: a service request is not a chargeable product/order and cannot
-- change table occupancy, billing, or checkout state.
