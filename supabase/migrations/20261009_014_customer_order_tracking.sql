-- Deploy after 008. Private bearer-token tracking; never expose customer phone or name.
create extension if not exists pgcrypto with schema extensions;
alter table public.gs_public_order_requests add column if not exists tracking_token_hash text;
create unique index if not exists gs_public_order_tracking_hash_idx on public.gs_public_order_requests(tracking_token_hash) where tracking_token_hash is not null;
create or replace function public.gs_submit_public_order(p_name text,p_phone text,p_notes text,p_items jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_total bigint; v_count int; v_token text;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100 or length(trim(coalesce(p_phone,''))) not between 6 and 30
 or length(coalesce(p_notes,''))>500 or jsonb_typeof(p_items) is distinct from 'array'
 or jsonb_array_length(p_items) not between 1 and 30 then raise exception 'Invalid request'; end if;
 if not exists(select 1 from public.cafe_website_settings s where s.id=1 and s.menu_enabled=true) then raise exception 'Ordering unavailable'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e where (e->>'product_id') !~ '^[0-9]+$' or (e->>'quantity') !~ '^[0-9]+$') then raise exception 'Invalid items'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e where (e->>'quantity')::numeric not between 1 and 20) then raise exception 'Invalid quantities'; end if;
 select count(*),sum(p.normal_price_iqd * (e->>'quantity')::int) into v_count,v_total
 from jsonb_array_elements(p_items) e join public.gs_menu_products p on p.id=(e->>'product_id')::bigint and p.is_active;
 if v_count <> jsonb_array_length(p_items) or v_total is null or
 (select count(distinct e->>'product_id') from jsonb_array_elements(p_items) e) <> v_count then raise exception 'Unavailable or duplicate product'; end if;
 v_token=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.gs_public_order_requests(customer_name,phone,notes,total_iqd,tracking_token_hash)
 values(trim(p_name),trim(p_phone),nullif(trim(coalesce(p_notes,'')),''),v_total,encode(extensions.digest(v_token,'sha256'),'hex')) returning id into v_id;
 insert into public.gs_public_order_request_items(request_id,product_id,product_name,quantity,unit_price_iqd)
 select v_id,p.id,p.name,(e->>'quantity')::int,p.normal_price_iqd
 from jsonb_array_elements(p_items) e join public.gs_menu_products p on p.id=(e->>'product_id')::bigint;
 return jsonb_build_object('request_id',v_id,'tracking_token',v_token);
end $$;
revoke all on function public.gs_submit_public_order(text,text,text,jsonb) from public;
grant execute on function public.gs_submit_public_order(text,text,text,jsonb) to anon,authenticated;
create or replace function public.gs_track_public_order(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
 if p_token is null or p_token !~ '^[0-9a-f]{64}$' then return null; end if;
 select jsonb_build_object('status',r.status,'created_at',r.created_at,'total_iqd',r.total_iqd,
 'items',(select coalesce(jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity)), '[]'::jsonb)
 from public.gs_public_order_request_items i where i.request_id=r.id)) into v_result
 from public.gs_public_order_requests r where r.tracking_token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 return v_result;
end $$;
revoke all on function public.gs_track_public_order(text) from public;
grant execute on function public.gs_track_public_order(text) to anon,authenticated;
-- Production launch requires edge rate limiting and CAPTCHA for both public RPCs.
