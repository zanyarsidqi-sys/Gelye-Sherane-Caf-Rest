-- Upgrade 55 DRAFT: staff may REQUEST a complimentary offer, not approve it.
-- Owner authentication / step-up MFA / ledger settlement must be implemented
-- and tested before owner approvals can be enabled.
alter table public.gs_owner_guest_offers
  add column if not exists reason text,
  add column if not exists requested_amount_iqd bigint,
  add column if not exists order_id bigint references public.gs_orders(id);
alter table public.gs_owner_guest_offers
  add constraint gs_owner_guest_request_amount_nonnegative
  check (requested_amount_iqd is null or requested_amount_iqd > 0);
create unique index if not exists gs_owner_guest_one_pending_per_order
  on public.gs_owner_guest_offers(order_id)
  where order_id is not null and status='pending';

create or replace function public.gs_request_owner_guest_offer(
  p_visit_id bigint, p_order_id bigint, p_amount_iqd bigint, p_reason text
) returns bigint
language plpgsql security definer set search_path=''
as $$
declare
 v_order public.gs_orders%rowtype;
 v_visit public.gs_table_visits%rowtype;
 v_table_number text;
 v_id bigint;
 v_total bigint;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Complimentary request permission denied';
 end if;
 if p_visit_id is null or p_order_id is null or p_amount_iqd is null
    or p_amount_iqd <= 0 or p_reason is null
    or length(btrim(p_reason)) < 5 or length(p_reason) > 500 then
  raise exception 'Valid visit, order, amount and reason required';
 end if;
 select * into v_visit from public.gs_table_visits
   where id=p_visit_id and status='active' for update;
 if not found then raise exception 'Active visit not found'; end if;
 select * into v_order from public.gs_orders
   where id=p_order_id and table_visit_id=p_visit_id and is_motel=false
   for update;
 if not found then raise exception 'Order does not belong to this visit'; end if;
 if v_order.status='cancelled' then raise exception 'Cancelled order'; end if;
 select sum(i.line_total_iqd) into v_total from public.gs_order_items i
  where i.order_id=p_order_id;
 if v_total is null or p_amount_iqd>v_total then
  raise exception 'Requested amount exceeds order total';
 end if;
 if exists (select 1 from public.gs_owner_guest_offers o
   where o.order_id=p_order_id and o.status in ('pending','verified')) then
  raise exception 'Existing owner offer requires review';
 end if;
 select t.table_number::text into v_table_number from public.gs_cafe_tables t
  where t.id=v_visit.table_id;
 insert into public.gs_owner_guest_offers(
  table_reference,table_visit_id,order_id,requested_by,status,
  complimentary_amount_iqd,requested_amount_iqd,reason)
 values(v_table_number,p_visit_id,p_order_id,auth.uid(),'pending',
  0,p_amount_iqd,btrim(p_reason)) returning id into v_id;
 insert into public.gs_system_audit_events(
  actor_id,section,action,record_id,after_data)
 values(auth.uid(),'table_orders','owner_guest_offer_requested',v_id::text,
  jsonb_build_object('visit_id',p_visit_id,'order_id',p_order_id,
  'requested_amount_iqd',p_amount_iqd,'status','pending'));
 return v_id;
end; $$;
revoke all on function public.gs_request_owner_guest_offer(bigint,bigint,bigint,text)
 from public,anon;
grant execute on function public.gs_request_owner_guest_offer(bigint,bigint,bigint,text)
 to authenticated;

-- Explicitly NO owner approval RPC yet: cannot claim 'Owner Verified' or
-- apply complimentary amounts without a verified owner identity + AAL2,
-- locked eligible item/bill allocation, financial posting, and audit.
-- This function leaves customer balance and recorded revenue unchanged.
