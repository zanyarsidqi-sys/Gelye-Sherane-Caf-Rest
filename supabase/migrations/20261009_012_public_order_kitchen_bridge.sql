-- Apply after migrations 001, 008, 009, 010 and 011. Review against live schema.
-- Staff acceptance atomically creates a real kitchen order from the public order snapshot.
create table if not exists public.gs_public_order_fulfillment (
  request_id uuid primary key references public.gs_public_order_requests(id),
  order_id bigint not null unique references public.gs_orders(id),
  accepted_by uuid not null references auth.users(id),
  accepted_at timestamptz not null default now()
);
alter table public.gs_public_order_fulfillment enable row level security;
revoke all on public.gs_public_order_fulfillment from public, anon, authenticated;

create or replace function public.gs_staff_review_public_request(p_type text,p_id uuid,p_action text)
returns text language plpgsql security definer set search_path = '' as $$
declare old_state text; next_state text; v_order_id bigint; v_total bigint; v_items bigint;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
   raise exception 'Not authorized';
 end if;
 if p_type='order' and p_action in ('accept','decline') then
   next_state := case when p_action='accept' then 'accepted' else 'declined' end;
   select status into old_state from public.gs_public_order_requests where id=p_id for update;
   if not found then raise exception 'Order request not found'; end if;
   if old_state <> 'pending' then raise exception 'Request no longer pending'; end if;
   if p_action='accept' then
     -- Reject empty/corrupt order snapshots rather than creating empty kitchen tickets.
     select count(*), coalesce(sum(quantity * unit_price_iqd),0)
       into v_items,v_total from public.gs_public_order_request_items where request_id=p_id;
     if v_items=0 or v_total <> (select total_iqd from public.gs_public_order_requests where id=p_id) then
       raise exception 'Order snapshot does not match request total';
     end if;
     insert into public.gs_orders(created_by,destination,is_motel,tourism_mode,status)
       values(auth.uid(),'Public online order ' || p_id::text,false,false,'new') returning id into v_order_id;
     insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd)
       select v_order_id,product_id,quantity,unit_price_iqd
       from public.gs_public_order_request_items where request_id=p_id;
     insert into public.gs_public_order_fulfillment(request_id,order_id,accepted_by)
       values(p_id,v_order_id,auth.uid());
   end if;
   update public.gs_public_order_requests set status=next_state where id=p_id;
 elsif p_type='reservation' and p_action in ('approve','decline') then
   next_state := case when p_action='approve' then 'approved' else 'declined' end;
   select status into old_state from public.gs_public_reservation_requests where id=p_id for update;
   if not found then raise exception 'Reservation not found'; end if;
   if old_state <> 'pending' then raise exception 'Request no longer pending'; end if;
   -- Retains the existing reservation capacity trigger/guard installed by migration 010.
   update public.gs_public_reservation_requests set status=next_state where id=p_id;
 else
   raise exception 'Invalid review action';
 end if;
 insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
   values(p_type,p_id,old_state,next_state,auth.uid());
 return next_state;
end $$;
revoke all on function public.gs_staff_review_public_request(text,uuid,text) from public;
grant execute on function public.gs_staff_review_public_request(text,uuid,text) to authenticated;
-- Kitchen panel already reads gs_orders and gs_order_items. This bridge puts accepted
-- public orders into that same queue without trusting client-side totals or prices.
