-- Upgrade 59: safe, read-only join-tables transfer eligibility review.
-- This does not move an item, payment, guest or balance.
create or replace function public.gs_preview_table_bill_transfer(
 p_source_visit_id bigint, p_destination_visit_id bigint
) returns table(
 order_item_id bigint, order_id bigint, product_id bigint,
 original_quantity integer, original_unit_price_iqd bigint,
 line_total_iqd bigint, order_cash_paid_iqd bigint,
 transfer_eligible boolean, restriction_reason text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_source public.gs_table_visits%rowtype;
        v_dest public.gs_table_visits%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view')
    or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Transfer preview permission denied';
 end if;
 if p_source_visit_id is null or p_destination_visit_id is null
    or p_source_visit_id=p_destination_visit_id then
  raise exception 'Choose two different visits';
 end if;
 select * into v_source from public.gs_table_visits
  where id=p_source_visit_id and status='active';
 if not found then raise exception 'Source visit is not active'; end if;
 select * into v_dest from public.gs_table_visits
  where id=p_destination_visit_id and status='active';
 if not found then raise exception 'Destination visit is not active'; end if;
 if v_source.table_id=v_dest.table_id then
  raise exception 'Source and destination tables must differ';
 end if;
 if not exists(select 1 from public.gs_cafe_tables t
   where t.id=v_source.table_id and t.occupied=true and t.cleaning_needed=false)
 or not exists(select 1 from public.gs_cafe_tables t
   where t.id=v_dest.table_id and t.occupied=true and t.cleaning_needed=false) then
  raise exception 'Both tables must be occupied and not cleaning';
 end if;
 return query
 select i.id,o.id,i.product_id,i.quantity,i.unit_price_iqd,
  i.line_total_iqd,coalesce(p.paid,0)::bigint,
  (o.status<>'cancelled' and coalesce(p.paid,0)=0
   and not exists(select 1 from public.gs_owner_guest_offers g
                  where g.order_id=o.id and g.status in ('pending','verified'))
   and not exists(select 1 from public.gs_table_bill_transfer_request_items ri
      join public.gs_table_bill_transfer_requests r on r.id=ri.transfer_request_id
      where ri.order_item_id=i.id and r.status in ('pending','approved','applied'))),
  case when o.status='cancelled' then 'cancelled_order'
       when coalesce(p.paid,0)>0 then 'order_has_cash_payment_do_not_split_without_ledger'
       when exists(select 1 from public.gs_owner_guest_offers g
                    where g.order_id=o.id and g.status in ('pending','verified'))
            then 'owner_offer_requires_review'
       when exists(select 1 from public.gs_table_bill_transfer_request_items ri
         join public.gs_table_bill_transfer_requests r on r.id=ri.transfer_request_id
         where ri.order_item_id=i.id and r.status in ('pending','approved','applied'))
            then 'existing_transfer_request'
       else 'cash_only_precheck_passed_other_payment_methods_unverified'
  end::text
 from public.gs_orders o
 join public.gs_order_items i on i.order_id=o.id
 left join lateral(select sum(c.amount_iqd)::bigint as paid
  from public.gs_cash_payments c where c.order_id=o.id) p on true
 where o.table_visit_id=p_source_visit_id and o.is_motel=false
 order by o.id,i.id;
end; $$;
revoke all on function public.gs_preview_table_bill_transfer(bigint,bigint)
 from public,anon;
grant execute on function public.gs_preview_table_bill_transfer(bigint,bigint)
 to authenticated;
-- WARNING: transfer_eligible means cash-only precheck, NOT authorization to
-- execute. Credit, card, online and other settlement ledgers are not covered.
-- Final transfer must lock both visits/orders, enforce capacity, audit, and
-- preserve original pricing and settlement allocations transactionally.
