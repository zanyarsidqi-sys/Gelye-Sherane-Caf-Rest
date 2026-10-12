-- Upgrade 353: staff review queue for motel guest food requests.
create table if not exists public.gs_motel_food_request_audit (
 id uuid primary key default extensions.gen_random_uuid(),
 request_id uuid not null references public.gs_motel_guest_food_requests(id),
 actor_id uuid not null references auth.users(id),
 old_status text not null, new_status text not null,
 reason text, changed_at timestamptz not null default now()
);
alter table public.gs_motel_food_request_audit enable row level security;
revoke all on public.gs_motel_food_request_audit from public,anon,authenticated;
create or replace function public.gs_staff_list_motel_food_requests()
returns table(id uuid,room_label text,room_name text,status text,total_iqd bigint,created_at timestamptz,items jsonb)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Not authorized'; end if;
 return query select o.id,r.room_label,r.room_name,o.status,o.total_iqd,o.created_at,
 coalesce((select jsonb_agg(jsonb_build_object('name',i.product_name,'quantity',i.quantity,'price_iqd',i.unit_price_iqd)
 order by i.product_name) from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'[]'::jsonb)
 from public.gs_motel_guest_food_requests o join public.gs_motel_room_qr r on r.id=o.room_id
 order by case when o.status='pending' then 0 else 1 end,o.created_at desc limit 200;
end; $$;
create or replace function public.gs_staff_decide_motel_food_request(p_request_id uuid,p_decision text,p_reason text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare v_status text; v_new text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false) then
  raise exception 'Not authorized'; end if;
 if p_decision not in ('accept','reject') then raise exception 'Invalid decision'; end if;
 if p_decision='reject' and length(trim(coalesce(p_reason,'')))<3 then raise exception 'Rejection reason required'; end if;
 select status into v_status from public.gs_motel_guest_food_requests where id=p_request_id for update;
 if not found then raise exception 'Request not found'; end if;
 if v_status<>'pending' then raise exception 'Request has already been reviewed'; end if;
 v_new:=case when p_decision='accept' then 'accepted' else 'rejected' end;
 update public.gs_motel_guest_food_requests set status=v_new where id=p_request_id;
 insert into public.gs_motel_food_request_audit(request_id,actor_id,old_status,new_status,reason)
 values(p_request_id,auth.uid(),v_status,v_new,nullif(trim(coalesce(p_reason,'')),''));
 return v_new;
end; $$;
revoke all on function public.gs_staff_list_motel_food_requests() from public;
revoke all on function public.gs_staff_decide_motel_food_request(uuid,text,text) from public;
grant execute on function public.gs_staff_list_motel_food_requests() to authenticated;
grant execute on function public.gs_staff_decide_motel_food_request(uuid,text,text) to authenticated;
