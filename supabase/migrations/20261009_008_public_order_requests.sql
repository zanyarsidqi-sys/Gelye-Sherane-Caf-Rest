-- Public order requests are separate from authenticated staff orders.
-- Deploy only after reviewing permissions, rate limits and product catalog.
create table if not exists public.gs_public_order_requests (
 id uuid primary key default gen_random_uuid(), customer_name text not null,
 phone text not null, notes text, status text not null default 'pending'
 check (status in ('pending','accepted','declined','cancelled','fulfilled')),
 total_iqd bigint not null check(total_iqd >= 0), created_at timestamptz not null default now());
create table if not exists public.gs_public_order_request_items (
 request_id uuid not null references public.gs_public_order_requests(id),
 product_id bigint not null references public.gs_menu_products(id),
 product_name text not null, quantity integer not null check(quantity between 1 and 20),
 unit_price_iqd bigint not null check(unit_price_iqd >= 0), primary key(request_id,product_id));
alter table public.gs_public_order_requests enable row level security;
alter table public.gs_public_order_request_items enable row level security;
revoke all on public.gs_public_order_requests from anon,authenticated;
revoke all on public.gs_public_order_request_items from anon,authenticated;
create or replace function public.gs_public_order_menu()
returns table(id bigint,name text,price_iqd bigint)
language sql stable security definer set search_path = '' as $$
 select p.id,p.name,p.normal_price_iqd from public.gs_menu_products p
 where p.is_active and exists(select 1 from public.cafe_website_settings s where s.id=1 and s.menu_enabled=true)
 order by p.name limit 500; $$;
revoke all on function public.gs_public_order_menu() from public;
grant execute on function public.gs_public_order_menu() to anon,authenticated;
create or replace function public.gs_submit_public_order(p_name text,p_phone text,p_notes text,p_items jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_total bigint; v_count int;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100
 or length(trim(coalesce(p_phone,''))) not between 6 and 30
 or length(coalesce(p_notes,''))>500 or jsonb_typeof(p_items) is distinct from 'array'
 or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'Invalid request'; end if;
 if not exists(select 1 from public.cafe_website_settings s where s.id=1 and s.menu_enabled=true) then raise exception 'Ordering unavailable'; end if;
 -- Aggregate duplicate product ids, validate each quantity and reject missing/inactive items.
 if exists(select 1 from jsonb_array_elements(p_items) e
 where (e->>'product_id') !~ '^[0-9]+$' or (e->>'quantity') !~ '^[0-9]+$') then raise exception 'Invalid items'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e where (e->>'quantity')::int not between 1 and 20) then raise exception 'Invalid quantities'; end if;
 select count(*),sum(p.normal_price_iqd * (e->>'quantity')::int)
 into v_count,v_total from jsonb_array_elements(p_items) e
 join public.gs_menu_products p on p.id=(e->>'product_id')::bigint and p.is_active;
 if v_count <> jsonb_array_length(p_items) or v_total is null then raise exception 'Unavailable product'; end if;
 if (select count(distinct e->>'product_id') from jsonb_array_elements(p_items) e) <> v_count then raise exception 'Duplicate product'; end if;
 insert into public.gs_public_order_requests(customer_name,phone,notes,total_iqd)
 values(trim(p_name),trim(p_phone),nullif(trim(coalesce(p_notes,'')),''),v_total) returning id into v_id;
 insert into public.gs_public_order_request_items(request_id,product_id,product_name,quantity,unit_price_iqd)
 select v_id,p.id,p.name,(e->>'quantity')::int,p.normal_price_iqd
 from jsonb_array_elements(p_items) e join public.gs_menu_products p on p.id=(e->>'product_id')::bigint;
 return v_id;
end $$;
revoke all on function public.gs_submit_public_order(text,text,text,jsonb) from public;
grant execute on function public.gs_submit_public_order(text,text,text,jsonb) to anon,authenticated;
-- REQUIRED BEFORE PUBLIC LAUNCH: edge rate limiting, CAPTCHA, staff review UI,
-- abuse monitoring, and a server-side order-enabled switch.
