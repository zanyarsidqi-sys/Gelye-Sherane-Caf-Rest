-- Upgrade 1186: visit-scoped customer preparation tracking; no staff identities or other visits exposed.
create or replace function public.gs_customer_visit_station_tracking(p_session_token uuid)
returns table(order_id bigint, station_name text, preparation_state text,
 estimated_ready_at timestamptz, estimated_minutes integer,
 ready_at timestamptz, picked_up_at timestamptz, delivered_at timestamptz)
language sql stable security definer set search_path = '' as $$
 select o.id, st.display_name::text,
   case when prep.delivered_at is not null then 'delivered'
        when prep.picked_up_at is not null then 'picked_up'
        else coalesce(prep.state,'pending') end::text,
   prep.estimated_ready_at, prep.estimated_minutes,
   prep.ready_at, prep.picked_up_at, prep.delivered_at
 from public.gs_customer_visit_sessions sess
 join public.gs_cafe_tables tbl on tbl.id=sess.table_id and tbl.occupied=true
 join public.gs_table_visits v on v.id=sess.visit_id
    and v.table_id=sess.table_id and v.status='open'
 join public.gs_orders o on o.table_visit_id=v.id and o.status<>'cancelled'
 join public.gs_cafe_order_station_tickets ticket on ticket.order_id=o.id
 join public.gs_cafe_preparation_stations st on st.station_key=ticket.station_key
 left join public.gs_cafe_station_preparation prep on prep.ticket_id=ticket.id
 where sess.session_token=p_session_token and sess.revoked_at is null
   and sess.expires_at>now()
 order by o.id desc, st.display_name, ticket.id
 limit 250;
$$;
revoke all on function public.gs_customer_visit_station_tracking(uuid) from public;
grant execute on function public.gs_customer_visit_station_tracking(uuid) to anon,authenticated;
