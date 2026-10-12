-- Upgrade 179: table-free takeaway/delivery intake, separate from financial orders.
create table if not exists public.gs_counter_order_requests (
 id bigint generated always as identity primary key,
 order_type text not null check(order_type in ('pickup','delivery')),
 customer_name text not null,
 customer_phone text,
 delivery_instructions text,
 items_notes text not null,
 status text not null default 'pending' check(status in
  ('pending','accepted','preparing','ready','picked_up','delivered','cancelled')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists gs_counter_order_requests_queue
 on public.gs_counter_order_requests(status,created_at desc);
alter table public.gs_counter_order_requests enable row level security;
revoke all on public.gs_counter_order_requests from public,anon,authenticated;
-- This is an intake/request queue, not a paid order or kitchen ticket.
create or replace function public.gs_create_counter_order_request(
 p_type text,p_customer_name text,p_phone text,p_items_notes text,
 p_delivery_instructions text default null)
returns bigint language plpgsql security definer
set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
   raise exception 'Not authorized for counter order intake';
 end if;
 if p_type not in ('pickup','delivery')
 or length(trim(coalesce(p_customer_name,''))) not between 2 and 100
 or length(coalesce(p_phone,'')) > 30
 or length(trim(coalesce(p_items_notes,''))) not between 3 and 2000
 or length(coalesce(p_delivery_instructions,'')) > 500
 then raise exception 'Invalid counter order request'; end if;
 insert into public.gs_counter_order_requests(
   order_type,customer_name,customer_phone,items_notes,delivery_instructions,created_by)
 values(p_type,trim(p_customer_name),nullif(trim(coalesce(p_phone,'')),''),
 trim(p_items_notes),nullif(trim(coalesce(p_delivery_instructions,'')),''),
 auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_create_counter_order_request(text,text,text,text,text)
 from public,anon;
grant execute on function public.gs_create_counter_order_request(text,text,text,text,text)
 to authenticated;

create or replace function public.gs_list_counter_order_requests()
returns table(id bigint,order_type text,customer_name text,
 items_notes text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Not authorized to view counter order requests';
 end if;
 return query select q.id,q.order_type,q.customer_name,q.items_notes,
 q.status,q.created_at from public.gs_counter_order_requests q
 order by q.created_at desc limit 100;
end; $$;
revoke all on function public.gs_list_counter_order_requests() from public,anon;
grant execute on function public.gs_list_counter_order_requests() to authenticated;
