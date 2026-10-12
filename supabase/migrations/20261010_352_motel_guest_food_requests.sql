-- Upgrade 352: authenticated-stay food requests; price snapshot calculated by server.
-- This is a request queue, not a kitchen ticket, inventory deduction, or bill.
create table if not exists public.gs_motel_guest_food_requests (
 id uuid primary key default extensions.gen_random_uuid(),
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 request_key text not null,
 status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
 total_iqd bigint not null check (total_iqd >= 0),
 created_at timestamptz not null default now(),
 unique (guest_session_id,request_key)
);
create table if not exists public.gs_motel_guest_food_request_items (
 id uuid primary key default extensions.gen_random_uuid(),
 request_id uuid not null references public.gs_motel_guest_food_requests(id),
 product_id bigint not null references public.gs_menu_products(id),
 product_name text not null,
 quantity integer not null check (quantity between 1 and 20),
 unit_price_iqd bigint not null check (unit_price_iqd >= 0),
 line_total_iqd bigint not null check (line_total_iqd >= 0),
 unique(request_id,product_id)
);
alter table public.gs_motel_guest_food_requests enable row level security;
alter table public.gs_motel_guest_food_request_items enable row level security;
revoke all on public.gs_motel_guest_food_requests,public.gs_motel_guest_food_request_items from public,anon,authenticated;
create or replace function public.gs_public_submit_motel_food_order(
 p_room_token text,p_access_token text,p_request_key text,p_items jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_session uuid; v_room uuid; v_id uuid; v_item jsonb;
 v_product bigint; v_qty integer; v_name text; v_price bigint; v_total bigint:=0;
 v_seen bigint[]:=array[]::bigint[]; v_count integer:=0;
begin
 begin
  select s.id,r.id into v_session,v_room from public.gs_motel_room_qr r
  join public.gs_motel_guest_stay_sessions s on s.room_id=r.id
  where r.public_token=p_room_token::uuid and s.access_token=p_access_token::uuid
   and r.is_active and s.revoked_at is null and s.expires_at>now();
 exception when invalid_text_representation then raise exception 'Invalid guest access'; end;
 if v_session is null then raise exception 'Invalid or expired guest access'; end if;
 if p_request_key is null or length(p_request_key) not between 8 and 120 then
  raise exception 'Invalid request identifier'; end if;
 select id into v_id from public.gs_motel_guest_food_requests
 where guest_session_id=v_session and request_key=p_request_key;
 if v_id is not null then return v_id; end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 30 then
  raise exception 'Invalid order items'; end if;
 if not exists(select 1 from public.cafe_website_settings where id=1 and menu_enabled=true) then
  raise exception 'Guest menu unavailable'; end if;
 -- Create request and price-snapshotted lines atomically; exceptions roll back everything.
 insert into public.gs_motel_guest_food_requests(guest_session_id,room_id,request_key,total_iqd)
 values(v_session,v_room,p_request_key,0) returning id into v_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  begin
   v_product := (v_item->>'product_id')::bigint;
   v_qty := (v_item->>'quantity')::integer;
  exception when invalid_text_representation or numeric_value_out_of_range then
   raise exception 'Invalid product or quantity'; end;
  if v_product is null or v_qty is null or v_qty not between 1 and 20
   or v_product=any(v_seen) then raise exception 'Invalid or duplicate order item'; end if;
  v_seen:=array_append(v_seen,v_product);
  select name,tourism_price_iqd into v_name,v_price from public.gs_menu_products
   where id=v_product and is_active=true;
  if not found or v_price is null or v_price < 0 then raise exception 'Product unavailable'; end if;
  v_total:=v_total+v_price*v_qty;
  if v_total>1000000000 then raise exception 'Order exceeds allowed total'; end if;
  insert into public.gs_motel_guest_food_request_items
   (request_id,product_id,product_name,quantity,unit_price_iqd,line_total_iqd)
  values(v_id,v_product,v_name,v_qty,v_price,v_price*v_qty);
  v_count:=v_count+1;
 end loop;
 update public.gs_motel_guest_food_requests set total_iqd=v_total where id=v_id;
 return v_id;
end; $$;
revoke all on function public.gs_public_submit_motel_food_order(text,text,text,jsonb) from public;
grant execute on function public.gs_public_submit_motel_food_order(text,text,text,jsonb) to anon,authenticated;
