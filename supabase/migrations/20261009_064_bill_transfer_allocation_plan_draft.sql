-- Upgrade 64: immutable payment allocation plan foundation (DRAFT).
-- No money movement or transfer execution is enabled.
-- An allocation plan is NOT proof of payment or permission to transfer.
create table if not exists public.gs_bill_transfer_allocation_plans (
 id bigint generated always as identity primary key,
 transfer_request_id bigint not null unique
   references public.gs_table_bill_transfer_requests(id) on delete restrict,
 source_visit_id bigint not null references public.gs_table_visits(id),
 destination_visit_id bigint not null references public.gs_table_visits(id),
 proposed_value_iqd bigint not null check(proposed_value_iqd>0),
 plan_status text not null default 'review_required'
   check(plan_status in ('review_required','invalidated','superseded')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id),
 note text not null default 'Not authorized for execution'
);
create table if not exists public.gs_bill_transfer_allocation_plan_items (
 id bigint generated always as identity primary key,
 plan_id bigint not null
   references public.gs_bill_transfer_allocation_plans(id) on delete restrict,
 order_item_id bigint not null references public.gs_order_items(id),
 quantity integer not null check(quantity>0),
 original_unit_price_iqd bigint not null check(original_unit_price_iqd>=0),
 proposed_value_iqd bigint generated always as
   (quantity::bigint*original_unit_price_iqd) stored,
 unique(plan_id,order_item_id)
);
create index if not exists gs_bill_transfer_plan_items_order_idx
 on public.gs_bill_transfer_allocation_plan_items(order_item_id);
alter table public.gs_bill_transfer_allocation_plans enable row level security;
alter table public.gs_bill_transfer_allocation_plan_items enable row level security;
revoke all on public.gs_bill_transfer_allocation_plans
 from public,anon,authenticated;
revoke all on public.gs_bill_transfer_allocation_plan_items
 from public,anon,authenticated;
-- No insert/update/delete RPCs: plans cannot be created by staff until
-- every payment source has an authoritative, verifiable ledger.

create or replace function public.gs_bill_transfer_allocation_readiness(p_request_id bigint)
returns table(
 transfer_request_id bigint, selected_items bigint,
 proposed_total_iqd bigint, cash_payment_count bigint,
 external_payment_count bigint, owner_offer_count bigint,
 execution_permitted boolean, review_reason text
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_request public.gs_table_bill_transfer_requests%rowtype;
begin
 if auth.uid() is null
  or not public.gs_can_access('table_orders','can_view')
  or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Allocation review access denied';
 end if;
 select * into v_request from public.gs_table_bill_transfer_requests
  where id=p_request_id;
 if not found then raise exception 'Transfer request not found'; end if;
 return query
 with selected as (
  select ri.order_item_id,ri.requested_quantity,
   oi.unit_price_iqd,oi.order_id
  from public.gs_table_bill_transfer_request_items ri
  join public.gs_order_items oi on oi.id=ri.order_item_id
  where ri.transfer_request_id=p_request_id
 ), affected_orders as (
  select distinct order_id from selected
 ), counts as (
  select
   (select count(*) from selected)::bigint item_count,
   (select coalesce(sum(requested_quantity::bigint*unit_price_iqd),0)
     from selected)::bigint total_value,
   (select count(*) from public.gs_cash_payments c
      join affected_orders a on a.order_id=c.order_id)::bigint cash_count,
   (select count(*) from public.gs_external_payment_evidence e
      join affected_orders a on a.order_id=e.order_id)::bigint external_count,
   (select count(*) from public.gs_owner_guest_offers g
      join affected_orders a on a.order_id=g.order_id
      where g.status in ('pending','verified'))::bigint offer_count
 )
 select p_request_id,c.item_count,c.total_value,
   c.cash_count,c.external_count,c.offer_count,
   false,
   case
    when v_request.status<>'pending' then 'request_not_pending'
    when c.item_count=0 then 'no_items_selected'
    when c.total_value<=0 then 'no_positive_transfer_value'
    when c.cash_count>0 then 'cash_allocation_required'
    when c.external_count>0 then 'external_payment_allocation_required'
    when c.offer_count>0 then 'owner_waiver_allocation_required'
    else 'authoritative_settlement_and_execution_engine_missing'
   end::text
 from counts c;
end; $$;
revoke all on function public.gs_bill_transfer_allocation_readiness(bigint)
 from public,anon;
grant execute on function public.gs_bill_transfer_allocation_readiness(bigint)
 to authenticated;
