-- Upgrade 1207: read-only, permission-scoped delivery inbox with names and priority.
-- Never expose all employee profiles through direct table access.
create or replace function public.gs_replacement_delivery_priority_inbox(p_threshold_minutes integer default 15)
returns table(revision_id bigint,order_id bigint,station_key text,product_name text,quantity integer,
 ready_at timestamptz,assigned_to uuid,employee_name text,accepted_at timestamptz,
 picked_up_at timestamptz,delivered_at timestamptz,minutes_waiting integer,
 delivery_status text,priority text,priority_rank integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required'; end if;
 if p_threshold_minutes < 1 or p_threshold_minutes > 240 then
   raise exception 'Invalid overdue threshold'; end if;
 return query
 select r.id,r.order_id,r.station_key,p.name::text,r.quantity,r.preparation_ready_at,
 d.assigned_to,case when d.assigned_to is null then null
   else coalesce(nullif(ep.full_name,''),'Employee')::text end,
 d.accepted_at,d.picked_up_at,d.delivered_at,
 greatest(0,floor(extract(epoch from transaction_timestamp()-r.preparation_ready_at)/60))::integer,
 case when d.assigned_to is null then 'Unassigned'
   when d.accepted_at is null then 'Awaiting acceptance'
   when d.picked_up_at is null then 'Awaiting pickup'
   else 'Out for delivery' end::text,
 case when r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes)
   then 'Overdue' when d.assigned_to is null then 'Needs assignment'
   else 'Normal' end::text,
 case when r.preparation_ready_at <= transaction_timestamp()-make_interval(mins=>p_threshold_minutes)
   then 0 when d.assigned_to is null then 1 when d.accepted_at is null then 2
   when d.picked_up_at is null then 3 else 4 end::integer
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 join public.gs_order_items i on i.id=r.order_item_id
 join public.gs_menu_products p on p.id=i.product_id
 left join public.employee_profiles ep on ep.user_id=d.assigned_to
 where d.delivered_at is null and
  (d.assigned_to=auth.uid() or exists(select 1 from public.gs_cafe_station_supervisors s
   where s.employee_id=auth.uid() and s.active) or
   (d.assigned_to is null and public.gs_can_work_station(r.station_key)))
 order by 15 asc,r.preparation_ready_at asc,r.id asc limit 200;
end; $$;
revoke all on function public.gs_replacement_delivery_priority_inbox(integer) from public,anon;
grant execute on function public.gs_replacement_delivery_priority_inbox(integer) to authenticated;
