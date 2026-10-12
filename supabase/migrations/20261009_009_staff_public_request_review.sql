-- Staff review queue. Apply after migrations 005, 007, 008.
create table if not exists public.gs_public_request_review_audit (
 id bigint generated always as identity primary key,
 request_type text not null check(request_type in ('order','reservation')),
 request_id uuid not null,
 old_status text not null,
 new_status text not null,
 actor uuid not null references auth.users(id),
 changed_at timestamptz not null default now()
);
alter table public.gs_public_request_review_audit enable row level security;
revoke all on public.gs_public_request_review_audit from anon,authenticated;
create or replace function public.gs_staff_public_requests()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('view') then raise exception 'Not authorized'; end if;
 select jsonb_build_object(
  'orders',coalesce((select jsonb_agg(to_jsonb(o) order by o.created_at desc) from (select id,customer_name,phone,notes,status,total_iqd,created_at from public.gs_public_order_requests order by created_at desc limit 100) o),'[]'::jsonb),
  'reservations',coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc) from (select id,customer_name,phone,notes,status,party_size,requested_at,created_at from public.gs_public_reservation_requests order by created_at desc limit 100) r),'[]'::jsonb)
 ) into result;
 return result;
end $$;
revoke all on function public.gs_staff_public_requests() from public;
grant execute on function public.gs_staff_public_requests() to authenticated;
create or replace function public.gs_staff_review_public_request(p_type text,p_id uuid,p_action text)
returns text language plpgsql security definer set search_path = '' as $$
declare old_state text; next_state text;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then raise exception 'Not authorized'; end if;
 if p_type='order' and p_action in ('accept','decline') then
  next_state:=case when p_action='accept' then 'accepted' else 'declined' end;
  select status into old_state from public.gs_public_order_requests where id=p_id for update;
  if old_state is distinct from 'pending' then raise exception 'Request no longer pending'; end if;
  update public.gs_public_order_requests set status=next_state where id=p_id;
 elsif p_type='reservation' and p_action in ('approve','decline') then
  next_state:=case when p_action='approve' then 'approved' else 'declined' end;
  select status into old_state from public.gs_public_reservation_requests where id=p_id for update;
  if old_state is distinct from 'pending' then raise exception 'Request no longer pending'; end if;
  update public.gs_public_reservation_requests set status=next_state where id=p_id;
 else raise exception 'Invalid review action'; end if;
 insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
 values(p_type,p_id,old_state,next_state,auth.uid());
 return next_state;
end $$;
revoke all on function public.gs_staff_review_public_request(text,uuid,text) from public;
grant execute on function public.gs_staff_review_public_request(text,uuid,text) to authenticated;
-- Approval records a decision only; availability/capacity and operational fulfillment require separate validation.
