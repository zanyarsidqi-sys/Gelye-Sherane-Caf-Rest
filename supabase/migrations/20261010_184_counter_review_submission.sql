-- Upgrade 184: atomic intake submission to an internal review queue.
-- Does not dispatch to kitchen, create a gs_orders row, or post a payment.
create table if not exists public.gs_counter_submission_events (
 id bigint generated always as identity primary key,
 request_id bigint not null references public.gs_counter_order_requests(id),
 actor uuid not null references auth.users(id),
 event_type text not null check(event_type in ('submitted_for_review')),
 item_count integer not null check(item_count > 0),
 total_iqd bigint not null check(total_iqd >= 0),
 happened_at timestamptz not null default now(),
 unique(request_id,event_type)
);
alter table public.gs_counter_submission_events enable row level security;
revoke all on public.gs_counter_submission_events from public,anon,authenticated;

create or replace function public.gs_submit_counter_request_for_review(
 p_request_id bigint) returns bigint
language plpgsql volatile security definer set search_path='' as $$
declare v_request public.gs_counter_order_requests%rowtype;
 v_count integer; v_total bigint; v_event bigint;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Not authorized to submit counter requests'; end if;
 select * into v_request from public.gs_counter_order_requests
 where id=p_request_id for update;
 if not found then raise exception 'Counter request not found'; end if;
 if v_request.status <> 'pending' then
  raise exception 'Request has already been submitted or closed'; end if;
 select count(*)::integer,coalesce(sum(quantity::bigint*unit_price_iqd),0)::bigint
 into v_count,v_total from public.gs_counter_order_request_items
 where request_id=p_request_id;
 if v_count=0 then raise exception 'Add priced menu items before submission'; end if;
 insert into public.gs_counter_submission_events(
  request_id,actor,event_type,item_count,total_iqd)
 values(p_request_id,auth.uid(),'submitted_for_review',v_count,v_total)
 returning id into v_event;
 update public.gs_counter_order_requests
 set status='accepted',updated_at=now() where id=p_request_id;
 return v_event;
end; $$;
revoke all on function public.gs_submit_counter_request_for_review(bigint)
 from public,anon;
grant execute on function public.gs_submit_counter_request_for_review(bigint)
 to authenticated;
