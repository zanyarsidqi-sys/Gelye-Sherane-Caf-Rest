-- Upgrade 284: event reservation and advance catering request foundation.
-- Pending requests do not automatically create orders, kitchen tickets or payments.
create table if not exists public.gs_event_reservations (
 id uuid primary key default gen_random_uuid(),
 customer_name text not null check (char_length(customer_name) between 2 and 100),
 customer_phone text not null check (char_length(customer_phone) between 6 and 30),
 event_type text not null check (char_length(event_type) between 2 and 80),
 event_start timestamptz not null,
 event_end timestamptz not null,
 guest_count integer not null check (guest_count between 1 and 1000),
 requested_table_id uuid references public.gs_reservable_tables(id),
 business_model text not null check (business_model in ('products','rental','both')),
 requested_services text check (char_length(requested_services)<=2000),
 rental_quote_iqd bigint check (rental_quote_iqd>=0),
 status text not null default 'pending_admin' check (status in ('pending_admin','approved','rejected','cancelled','completed')),
 source text not null check (source in ('customer','staff')),
 created_by uuid,
 reviewed_by uuid,
 reviewed_at timestamptz,
 review_note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint gs_event_time_range check (event_end>event_start and event_end<=event_start+interval '24 hours')
);
create table if not exists public.gs_event_requested_products (
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.gs_event_reservations(id) on delete cascade,
 product_name text not null check (char_length(product_name) between 2 and 160),
 requested_quantity integer not null check (requested_quantity between 1 and 10000),
 requested_serve_at timestamptz,
 instructions text check (char_length(instructions)<=500),
 created_at timestamptz not null default now()
);
create table if not exists public.gs_event_review_audit (
 id bigint generated always as identity primary key,
 event_id uuid not null references public.gs_event_reservations(id),
 old_status text not null,
 new_status text not null,
 actor uuid not null,
 note text,
 changed_at timestamptz not null default now()
);
create index if not exists gs_event_reservations_dates_idx on public.gs_event_reservations(event_start,event_end,status);
create index if not exists gs_event_requested_products_event_idx on public.gs_event_requested_products(event_id);
alter table public.gs_event_reservations enable row level security;
alter table public.gs_event_requested_products enable row level security;
alter table public.gs_event_review_audit enable row level security;
revoke all on public.gs_event_reservations,public.gs_event_requested_products,public.gs_event_review_audit from anon,authenticated;

-- Staff-only submission until public edge rate limiting and CAPTCHA are deployed.
create or replace function public.gs_staff_request_event(
 p_customer_name text,p_customer_phone text,p_event_type text,
 p_start timestamptz,p_end timestamptz,p_guest_count integer,
 p_business_model text,p_table_id uuid default null,p_services text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized'; end if;
 if char_length(trim(coalesce(p_customer_name,''))) not between 2 and 100
 or char_length(trim(coalesce(p_customer_phone,''))) not between 6 and 30
 or char_length(trim(coalesce(p_event_type,''))) not between 2 and 80
 or p_start<=now() or p_start>now()+interval '365 days'
 or p_end<=p_start or p_end>p_start+interval '24 hours'
 or p_guest_count not between 1 and 1000
 or p_business_model not in ('products','rental','both')
 or char_length(coalesce(p_services,''))>2000 then
  raise exception 'Invalid event request'; end if;
 if p_table_id is not null and not exists (
  select 1 from public.gs_reservable_tables t
  where t.id=p_table_id and t.enabled and t.seats>=p_guest_count
 ) then raise exception 'Table unavailable or insufficient capacity'; end if;
 insert into public.gs_event_reservations
 (customer_name,customer_phone,event_type,event_start,event_end,guest_count,
 business_model,requested_table_id,requested_services,source,created_by)
 values(trim(p_customer_name),trim(p_customer_phone),trim(p_event_type),
 p_start,p_end,p_guest_count,p_business_model,p_table_id,p_services,'staff',auth.uid())
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_request_event(text,text,text,timestamptz,timestamptz,integer,text,uuid,text) from public,anon;
grant execute on function public.gs_staff_request_event(text,text,text,timestamptz,timestamptz,integer,text,uuid,text) to authenticated;

create or replace function public.gs_staff_add_event_product(
 p_event_id uuid,p_product_name text,p_quantity integer,
 p_serve_at timestamptz default null,p_instructions text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_event public.gs_event_reservations%rowtype;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
  raise exception 'Not authorized'; end if;
 select * into v_event from public.gs_event_reservations where id=p_event_id for update;
 if not found or v_event.status<>'pending_admin' then raise exception 'Event is not editable'; end if;
 if char_length(trim(coalesce(p_product_name,''))) not between 2 and 160
 or p_quantity not between 1 and 10000 or char_length(coalesce(p_instructions,''))>500
 or (p_serve_at is not null and (p_serve_at<v_event.event_start or p_serve_at>v_event.event_end))
 then raise exception 'Invalid product request'; end if;
 insert into public.gs_event_requested_products(event_id,product_name,requested_quantity,requested_serve_at,instructions)
 values(p_event_id,trim(p_product_name),p_quantity,p_serve_at,p_instructions) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_add_event_product(uuid,text,integer,timestamptz,text) from public,anon;
grant execute on function public.gs_staff_add_event_product(uuid,text,integer,timestamptz,text) to authenticated;
-- Admin approval RPC intentionally deferred until an existing authoritative admin-role predicate
-- and cross-module table conflict locks can be verified. Never approve by direct table UPDATE.
