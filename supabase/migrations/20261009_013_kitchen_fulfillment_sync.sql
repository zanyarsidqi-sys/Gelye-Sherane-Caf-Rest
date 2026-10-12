-- Phase 3: synchronize public request fulfillment with the kitchen's served status.
-- Prerequisites: migrations 001, 002, 008, 009, 012. Review against live schema.
-- Uses an AFTER UPDATE trigger so completion in any authorized kitchen workflow
-- updates the corresponding accepted public request in the same transaction.
create or replace function public.gs_sync_public_order_fulfillment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'served' and old.status is distinct from new.status then
    update public.gs_public_order_requests r
       set status = 'fulfilled'
      from public.gs_public_order_fulfillment f
     where f.order_id = new.id
       and f.request_id = r.id
       and r.status = 'accepted';
  end if;
  return new;
end;
$$;
revoke all on function public.gs_sync_public_order_fulfillment() from public, anon, authenticated;
drop trigger if exists gs_public_fulfillment_on_kitchen_served on public.gs_orders;
create trigger gs_public_fulfillment_on_kitchen_served
  after update of status on public.gs_orders
  for each row execute function public.gs_sync_public_order_fulfillment();

-- Read-only staff status view, respecting permission at query time.
create or replace function public.gs_staff_public_fulfillment_status()
returns table(request_id uuid, kitchen_order_id bigint, request_status text, kitchen_status text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.cafe_can_manage_website('view') then
   raise exception 'Not authorized';
 end if;
 return query
 select f.request_id, f.order_id, r.status, o.status
 from public.gs_public_order_fulfillment f
 join public.gs_public_order_requests r on r.id=f.request_id
 join public.gs_orders o on o.id=f.order_id
 order by f.accepted_at desc limit 200;
end;
$$;
revoke all on function public.gs_staff_public_fulfillment_status() from public;
grant execute on function public.gs_staff_public_fulfillment_status() to authenticated;
