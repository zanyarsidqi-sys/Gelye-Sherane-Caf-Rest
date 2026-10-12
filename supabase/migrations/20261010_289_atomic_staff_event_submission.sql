-- Upgrade 289: atomic staff event + advance product requests.
-- Entire request is committed or rolled back as one transaction.
create or replace function public.gs_staff_submit_event_with_products(
 p_customer_name text,p_customer_phone text,p_event_type text,
 p_start timestamptz,p_end timestamptz,p_guest_count integer,
 p_business_model text,p_table_id uuid,p_services text,p_products jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_item jsonb; v_count integer; v_serve timestamptz;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized' using errcode='42501'; end if;
 if p_products is null or jsonb_typeof(p_products)<>'array' then
  raise exception 'Products must be an array'; end if;
 v_count:=jsonb_array_length(p_products);
 if v_count>100 then raise exception 'Too many requested products'; end if;
 if p_business_model='rental' and v_count<>0 then
  raise exception 'Rental-only events cannot include products'; end if;
 if p_business_model='products' and v_count=0 then
  raise exception 'Product-sales events require products'; end if;
 if char_length(trim(coalesce(p_customer_name,''))) not between 2 and 100
 or char_length(trim(coalesce(p_customer_phone,''))) not between 6 and 30
 or char_length(trim(coalesce(p_event_type,''))) not between 2 and 80
 or p_start is null or p_end is null or p_start<=now()
 or p_start>now()+interval '365 days'
 or p_end<=p_start or p_end>p_start+interval '24 hours'
 or p_guest_count not between 1 and 1000
 or p_business_model not in ('products','rental','both')
 or char_length(coalesce(p_services,''))>2000 then
  raise exception 'Invalid event request'; end if;
 if p_table_id is not null then
  perform 1 from public.gs_reservable_tables t
   where t.id=p_table_id and t.enabled and t.seats>=p_guest_count for update;
  if not found then raise exception 'Table unavailable or insufficient capacity'; end if;
  if exists (
   select 1 from public.gs_event_reservations e
   where e.requested_table_id=p_table_id and e.status='approved'
   and e.event_start<p_end and e.event_end>p_start
  ) or exists (
   select 1 from public.gs_public_reservation_requests r
   where r.assigned_table_id=p_table_id and r.status='approved'
   and r.requested_at<p_end
   and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start
  ) then raise exception 'Table already reserved'; end if;
 end if;
 -- Validate the full product payload before writing the event.
 for v_item in select value from jsonb_array_elements(p_products) loop
  if jsonb_typeof(v_item)<>'object'
   or jsonb_typeof(v_item->'product_name')<>'string'
   or jsonb_typeof(v_item->'quantity')<>'number'
   or coalesce(v_item->>'quantity','') !~ '^[0-9]{1,5}$'
   or (v_item ? 'instructions' and jsonb_typeof(v_item->'instructions') not in ('string','null'))
   or (v_item ? 'serve_at' and jsonb_typeof(v_item->'serve_at') not in ('string','null'))
  then raise exception 'Invalid product payload'; end if;
  if char_length(trim(v_item->>'product_name')) not between 2 and 160
   or (v_item->>'quantity')::integer not between 1 and 10000
   or char_length(coalesce(v_item->>'instructions',''))>500
  then raise exception 'Invalid product request'; end if;
  v_serve:=nullif(v_item->>'serve_at','')::timestamptz;
  if v_serve is not null and (v_serve<p_start or v_serve>p_end) then
   raise exception 'Product serving time outside event'; end if;
 end loop;
 insert into public.gs_event_reservations
 (customer_name,customer_phone,event_type,event_start,event_end,guest_count,
 business_model,requested_table_id,requested_services,source,created_by)
 values(trim(p_customer_name),trim(p_customer_phone),trim(p_event_type),
 p_start,p_end,p_guest_count,p_business_model,p_table_id,p_services,'staff',auth.uid())
 returning id into v_id;
 for v_item in select value from jsonb_array_elements(p_products) loop
  insert into public.gs_event_requested_products
  (event_id,product_name,requested_quantity,requested_serve_at,instructions)
  values(v_id,trim(v_item->>'product_name'),(v_item->>'quantity')::integer,
    nullif(v_item->>'serve_at','')::timestamptz,v_item->>'instructions');
 end loop;
 return v_id;
end $$;
revoke all on function public.gs_staff_submit_event_with_products(
 text,text,text,timestamptz,timestamptz,integer,text,uuid,text,jsonb) from public,anon;
grant execute on function public.gs_staff_submit_event_with_products(
 text,text,text,timestamptz,timestamptz,integer,text,uuid,text,jsonb) to authenticated;
