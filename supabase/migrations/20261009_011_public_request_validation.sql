-- Defense in depth only. This is NOT IP/device rate limiting or CAPTCHA.
-- Run after migrations 007 and 008. Anonymous RPCs remain enabled.
create table if not exists public.gs_public_submission_limits (
  request_kind text not null check (request_kind in ('order','reservation')),
  phone_digest text not null,
  window_start timestamptz not null,
  submission_count integer not null default 0 check (submission_count >= 0),
  primary key (request_kind, phone_digest, window_start)
);
alter table public.gs_public_submission_limits enable row level security;
revoke all on public.gs_public_submission_limits from public, anon, authenticated;

create or replace function public.gs_check_public_submission(p_kind text, p_phone text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone,''), '[^0-9+]', '', 'g');
  v_window timestamptz := date_trunc('hour', now());
  v_count integer;
begin
  if p_kind not in ('order','reservation') or v_phone !~ '^\+?[0-9]{6,15}$' then
    raise exception 'Invalid request';
  end if;
  insert into public.gs_public_submission_limits(request_kind, phone_digest, window_start, submission_count)
  values (p_kind, md5(v_phone), v_window, 1)
  on conflict (request_kind, phone_digest, window_start)
  do update set submission_count = public.gs_public_submission_limits.submission_count + 1
  returning submission_count into v_count;
  if v_count > 3 then
    raise exception 'Too many requests. Please try again later.';
  end if;
end $$;
revoke all on function public.gs_check_public_submission(text,text) from public, anon, authenticated;

-- Recreate submit functions with server-side validation and phone-based throttle.
create or replace function public.gs_submit_reservation_request(p_name text, p_phone text, p_requested_at timestamptz, p_party_size integer, p_notes text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100
    or p_party_size not between 1 and 30 or p_requested_at is null
    or p_requested_at <= now() or p_requested_at > now() + interval '90 days'
    or length(coalesce(p_notes,'')) > 500 then
  raise exception 'Invalid reservation request';
 end if;
 perform public.gs_check_public_submission('reservation', p_phone);
 insert into public.gs_public_reservation_requests(customer_name,phone,requested_at,party_size,notes)
 values(trim(p_name),trim(p_phone),p_requested_at,p_party_size,nullif(trim(coalesce(p_notes,'')),'')) returning id into new_id;
 return new_id;
end $$;
revoke all on function public.gs_submit_reservation_request(text,text,timestamptz,integer,text) from public;
grant execute on function public.gs_submit_reservation_request(text,text,timestamptz,integer,text) to anon,authenticated;

create or replace function public.gs_submit_public_order(p_name text,p_phone text,p_notes text,p_items jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_total bigint; v_count integer;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100
 or length(coalesce(p_notes,'')) > 500
 or jsonb_typeof(p_items) is distinct from 'array'
 or jsonb_array_length(p_items) not between 1 and 30 then
   raise exception 'Invalid request';
 end if;
 if not exists(select 1 from public.cafe_website_settings s where s.id=1 and s.menu_enabled=true)
 then raise exception 'Ordering unavailable'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e
   where (e->>'product_id') !~ '^[0-9]{1,18}$'
   or (e->>'quantity') !~ '^[0-9]{1,2}$')
 then raise exception 'Invalid items'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) e
   where (e->>'quantity')::integer not between 1 and 20)
 then raise exception 'Invalid quantities'; end if;
 select count(*), sum(p.normal_price_iqd * (e->>'quantity')::integer)
 into v_count,v_total from jsonb_array_elements(p_items) e
 join public.gs_menu_products p on p.id=(e->>'product_id')::bigint and p.is_active;
 if v_count <> jsonb_array_length(p_items) or v_total is null
 or (select count(distinct e->>'product_id') from jsonb_array_elements(p_items) e) <> v_count
 then raise exception 'Unavailable or duplicate product'; end if;
 perform public.gs_check_public_submission('order', p_phone);
 insert into public.gs_public_order_requests(customer_name,phone,notes,total_iqd)
 values(trim(p_name),trim(p_phone),nullif(trim(coalesce(p_notes,'')),''),v_total) returning id into v_id;
 insert into public.gs_public_order_request_items(request_id,product_id,product_name,quantity,unit_price_iqd)
 select v_id,p.id,p.name,(e->>'quantity')::integer,p.normal_price_iqd
 from jsonb_array_elements(p_items) e join public.gs_menu_products p on p.id=(e->>'product_id')::bigint;
 return v_id;
end $$;
revoke all on function public.gs_submit_public_order(text,text,text,jsonb) from public;
grant execute on function public.gs_submit_public_order(text,text,text,jsonb) to anon,authenticated;

-- IMPORTANT: Phone-based limits are bypassable by changing phone numbers.
-- Production launch still requires trusted edge IP/device throttling, CAPTCHA,
-- abuse monitoring, and review of public RPC grants and website switches.
