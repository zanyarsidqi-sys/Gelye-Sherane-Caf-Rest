-- Upgrade 296: atomic staff event submission for entire venue or multiple tables.
create or replace function public.gs_staff_submit_scoped_event(
 p_customer_name text,p_customer_phone text,p_event_type text,
 p_start timestamptz,p_end timestamptz,p_guest_count integer,
 p_business_model text,p_services text,p_products jsonb,
 p_venue_scope text,p_table_ids uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_seats integer; v_count integer;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized' using errcode='42501'; end if;
 v_count:=coalesce(cardinality(p_table_ids),0);
 if p_venue_scope not in ('whole_venue','selected_tables') or p_venue_scope is null
  or (p_venue_scope='whole_venue' and v_count<>0)
  or (p_venue_scope='selected_tables' and (v_count<1 or v_count>30 or
    (select count(distinct x) from unnest(p_table_ids) x)<>v_count))
 then raise exception 'Invalid venue selection'; end if;
 perform pg_advisory_xact_lock(721903,1);
 if p_venue_scope='whole_venue' then
  select coalesce(sum(seats),0) into v_seats from public.gs_reservable_tables where enabled;
  if v_seats<p_guest_count then raise exception 'Insufficient venue capacity'; end if;
  if exists(select 1 from public.gs_event_reservations e where e.status='approved'
    and e.event_start<p_end and e.event_end>p_start)
    or exists(select 1 from public.gs_public_reservation_requests r
    where r.status='approved' and r.requested_at<p_end
    and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
  then raise exception 'Venue unavailable'; end if;
 else
  select coalesce(sum(seats),0) into v_seats from public.gs_reservable_tables
    where enabled and id=any(p_table_ids);
  if (select count(*) from public.gs_reservable_tables where enabled and id=any(p_table_ids))<>v_count
    or v_seats<p_guest_count then raise exception 'Invalid table capacity'; end if;
  if exists(select 1 from public.gs_event_reservations e where e.status='approved'
    and e.event_start<p_end and e.event_end>p_start
    and (e.venue_scope='whole_venue' or e.requested_table_id=any(p_table_ids)
    or exists(select 1 from public.gs_event_requested_tables x
       where x.event_id=e.id and x.table_id=any(p_table_ids))))
    or exists(select 1 from public.gs_public_reservation_requests r
      where r.status='approved' and r.assigned_table_id=any(p_table_ids)
      and r.requested_at<p_end
      and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
  then raise exception 'Selected tables unavailable'; end if;
 end if;
 -- Underlying function validates event fields and product quantities.
 v_id:=public.gs_staff_submit_event_with_products(
  p_customer_name,p_customer_phone,p_event_type,p_start,p_end,p_guest_count,
  p_business_model,null::uuid,p_services,p_products);
 update public.gs_event_reservations set venue_scope=p_venue_scope,
  requested_table_id=case when v_count=1 then p_table_ids[1] else null end,
  updated_at=now() where id=v_id;
 if p_venue_scope='selected_tables' then
  insert into public.gs_event_requested_tables(event_id,table_id)
  select v_id,x from unnest(p_table_ids) x;
 end if;
 return v_id;
end $$;
revoke all on function public.gs_staff_submit_scoped_event(text,text,text,timestamptz,timestamptz,integer,text,text,jsonb,text,uuid[]) from public,anon;
grant execute on function public.gs_staff_submit_scoped_event(text,text,text,timestamptz,timestamptz,integer,text,text,jsonb,text,uuid[]) to authenticated;

-- Available individual tables, including tables smaller than the total guest party.
create or replace function public.gs_staff_event_scope_options(p_start timestamptz,p_end timestamptz)
returns table(table_id uuid,table_label text,seats integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized' using errcode='42501'; end if;
 if p_start is null or p_end is null or p_start<=now() or p_start>now()+interval '365 days'
  or p_end<=p_start or p_end>p_start+interval '24 hours' then
  raise exception 'Invalid event time'; end if;
 return query select t.id,t.table_label,t.seats from public.gs_reservable_tables t
 where t.enabled
 and not exists(select 1 from public.gs_event_reservations e where e.status='approved'
  and e.event_start<p_end and e.event_end>p_start
  and (e.venue_scope='whole_venue' or e.requested_table_id=t.id
    or exists(select 1 from public.gs_event_requested_tables x where x.event_id=e.id and x.table_id=t.id)))
 and not exists(select 1 from public.gs_public_reservation_requests r
  where r.status='approved' and r.assigned_table_id=t.id
  and r.requested_at<p_end and r.requested_at+make_interval(mins=>r.duration_minutes)>p_start)
 order by t.table_label limit 200;
end $$;
revoke all on function public.gs_staff_event_scope_options(timestamptz,timestamptz) from public,anon;
grant execute on function public.gs_staff_event_scope_options(timestamptz,timestamptz) to authenticated;
