-- Upgrade 298: service-role-only, atomic public event submission.
create or replace function public.gs_public_event_create(
 p_customer_name text,p_customer_phone text,p_event_type text,
 p_start timestamptz,p_end timestamptz,p_guest_count integer,
 p_business_model text,p_services text,p_products jsonb,
 p_venue_scope text,p_table_ids uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_item jsonb; v_count int; v_capacity int;
begin
 if auth.role() <> 'service_role' then
  raise exception 'Not authorized' using errcode='42501';
 end if;
 if char_length(trim(coalesce(p_customer_name,''))) not between 2 and 100
 or char_length(trim(coalesce(p_customer_phone,''))) not between 6 and 30
 or char_length(trim(coalesce(p_event_type,''))) not between 2 and 80
 or p_start is null or p_end is null or p_start<=now()
 or p_start>now()+interval '365 days' or p_end<=p_start
 or p_end>p_start+interval '24 hours'
 or p_guest_count not between 1 and 1000
 or p_business_model not in ('products','rental','both')
 or p_venue_scope not in ('selected_tables','whole_venue')
 or char_length(coalesce(p_services,''))>2000
 or p_products is null or jsonb_typeof(p_products)<>'array'
 or jsonb_array_length(p_products)>100 then
  raise exception 'Invalid event request';
 end if;
 v_count:=coalesce(cardinality(p_table_ids),0);
 if (p_venue_scope='whole_venue' and v_count<>0)
 or (p_venue_scope='selected_tables' and
    (v_count<1 or v_count>30 or
     (select count(distinct x) from unnest(p_table_ids) x)<>v_count))
 or (p_business_model='rental' and jsonb_array_length(p_products)<>0)
 or (p_business_model='products' and jsonb_array_length(p_products)=0)
 then raise exception 'Invalid event selection'; end if;
 for v_item in select value from jsonb_array_elements(p_products) loop
  if jsonb_typeof(v_item)<>'object'
   or jsonb_typeof(v_item->'product_name')<>'string'
   or coalesce(v_item->>'quantity','') !~ '^[0-9]{1,5}$'
   or char_length(trim(v_item->>'product_name')) not between 2 and 160
   or (v_item->>'quantity')::int not between 1 and 10000
   or (v_item ? 'instructions' and jsonb_typeof(v_item->'instructions') not in ('string','null'))
   or char_length(coalesce(v_item->>'instructions',''))>500
   then raise exception 'Invalid product request'; end if;
 end loop;
 perform pg_advisory_xact_lock(721903,1);
 if p_venue_scope='whole_venue' then
  select coalesce(sum(seats),0) into v_capacity
  from public.gs_reservable_tables where enabled;
 else
  select coalesce(sum(seats),0) into v_capacity
  from public.gs_reservable_tables where enabled and id=any(p_table_ids);
  if (select count(*) from public.gs_reservable_tables
      where enabled and id=any(p_table_ids))<>v_count
  then raise exception 'Selected tables not available'; end if;
 end if;
 if v_capacity<p_guest_count then raise exception 'Insufficient seating capacity'; end if;
 if exists(select 1 from public.gs_event_reservations e
   where e.status='approved' and e.event_start<p_end and e.event_end>p_start
   and (p_venue_scope='whole_venue' or e.venue_scope='whole_venue'
    or e.requested_table_id=any(p_table_ids)
    or exists(select 1 from public.gs_event_requested_tables x
      where x.event_id=e.id and x.table_id=any(p_table_ids))))
 or exists(select 1 from public.gs_public_reservation_requests r
   where r.status='approved' and r.requested_at<p_end
   and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start
   and (p_venue_scope='whole_venue' or r.assigned_table_id=any(p_table_ids)))
 then raise exception 'Requested venue space is unavailable'; end if;
 insert into public.gs_event_reservations
 (customer_name,customer_phone,event_type,event_start,event_end,guest_count,
 business_model,requested_services,source,venue_scope,requested_table_id)
 values(trim(p_customer_name),trim(p_customer_phone),trim(p_event_type),
 p_start,p_end,p_guest_count,p_business_model,p_services,'customer',p_venue_scope,
 case when v_count=1 then p_table_ids[1] else null end)
 returning id into v_id;
 if p_venue_scope='selected_tables' then
  insert into public.gs_event_requested_tables(event_id,table_id)
   select v_id,x from unnest(p_table_ids) x;
 end if;
 for v_item in select value from jsonb_array_elements(p_products) loop
  insert into public.gs_event_requested_products
   (event_id,product_name,requested_quantity,instructions)
  values(v_id,trim(v_item->>'product_name'),(v_item->>'quantity')::int,
    v_item->>'instructions');
 end loop;
 return v_id;
end $$;
revoke all on function public.gs_public_event_create(text,text,text,timestamptz,timestamptz,integer,text,text,jsonb,text,uuid[]) from public,anon,authenticated;
grant execute on function public.gs_public_event_create(text,text,text,timestamptz,timestamptz,integer,text,text,jsonb,text,uuid[]) to service_role;
