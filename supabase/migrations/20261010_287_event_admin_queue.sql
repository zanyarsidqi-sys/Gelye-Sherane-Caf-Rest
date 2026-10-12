-- Upgrade 287: read-only admin queue, with no direct table access.
create or replace function public.gs_admin_event_queue(p_limit integer default 100)
returns table(event_id uuid,customer_name text,customer_phone text,event_type text,
 event_start timestamptz,event_end timestamptz,guest_count integer,
 requested_table_id uuid,business_model text,requested_services text,
 rental_quote_iqd bigint,status text,source text,created_at timestamptz,
 products jsonb)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'cafe_role','') <> 'admin'
 then raise exception 'Admin permission required' using errcode='42501'; end if;
 if p_limit is null or p_limit < 1 or p_limit > 200 then raise exception 'Invalid limit'; end if;
 return query
 select e.id,e.customer_name,e.customer_phone,e.event_type,e.event_start,e.event_end,
 e.guest_count,e.requested_table_id,e.business_model,e.requested_services,
 e.rental_quote_iqd,e.status,e.source,e.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('product_name',p.product_name,
 'quantity',p.requested_quantity,'serve_at',p.requested_serve_at,'instructions',p.instructions)
 order by p.product_name) from public.gs_event_requested_products p where p.event_id=e.id),'[]'::jsonb)
 from public.gs_event_reservations e
 where e.status in ('pending_admin','approved','rejected')
 order by case when e.status='pending_admin' then 0 else 1 end,e.created_at desc
 limit p_limit;
end $$;
revoke all on function public.gs_admin_event_queue(integer) from public,anon;
grant execute on function public.gs_admin_event_queue(integer) to authenticated;
