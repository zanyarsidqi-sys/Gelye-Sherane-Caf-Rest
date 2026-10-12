-- Upgrade 161: transfer-request financial safety validation (read-only).
-- Never authorizes, approves or executes transfers.
create or replace function public.gs_validate_table_bill_transfer_request(p_request_id bigint)
returns table(
 request_id bigint, request_status text, source_visit_active boolean,
 destination_visit_active boolean, source_destination_distinct boolean,
 source_order_count bigint, requested_item_count bigint,
 requested_value_iqd bigint, invalid_item_count bigint,
 cash_payment_count bigint, ledger_entry_count bigint,
 external_evidence_count bigint, owner_offer_count bigint,
 overlapping_request_count bigint, review_passed boolean,
 execution_permitted boolean, blocker_codes text[]
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_req public.gs_table_bill_transfer_requests%rowtype;
 v_source public.gs_table_visits%rowtype;
 v_dest public.gs_table_visits%rowtype;
 v_items bigint;
 v_invalid bigint;
 v_total bigint;
 v_orders bigint;
 v_cash bigint;
 v_ledger bigint;
 v_external bigint;
 v_offers bigint;
 v_overlap bigint;
 v_blockers text[] := array[]::text[];
begin
 if auth.uid() is null
   or not public.gs_can_access('table_orders','can_view')
   or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Transfer validation permission denied';
 end if;
 if p_request_id is null then raise exception 'Request id required'; end if;
 select * into v_req from public.gs_table_bill_transfer_requests
 where id=p_request_id;
 if not found then raise exception 'Transfer request not found'; end if;
 select * into v_source from public.gs_table_visits where id=v_req.source_visit_id;
 select * into v_dest from public.gs_table_visits where id=v_req.destination_visit_id;

 with selected as (
  select ri.order_item_id,ri.requested_quantity,oi.quantity,
    oi.unit_price_iqd,oi.order_id,o.table_visit_id,o.status as order_status
  from public.gs_table_bill_transfer_request_items ri
  left join public.gs_order_items oi on oi.id=ri.order_item_id
  left join public.gs_orders o on o.id=oi.order_id
  where ri.transfer_request_id=p_request_id
 ), affected as (
  select distinct order_id from selected where order_id is not null
 )
 select
   (select count(*) from selected),
   (select count(*) from selected where order_id is null
     or table_visit_id is distinct from v_req.source_visit_id
     or order_status='cancelled'
     or requested_quantity is null or requested_quantity<=0
     or quantity is null or requested_quantity>quantity
     or unit_price_iqd is null or unit_price_iqd<0),
   (select coalesce(sum(requested_quantity::bigint*unit_price_iqd),0)
      from selected),
   (select count(*) from affected),
   (select count(*) from public.gs_cash_payments p
      join affected a on a.order_id=p.order_id),
   (select count(*) from public.gs_unified_payment_ledger l
      join affected a on a.order_id=l.order_id),
   (select count(*) from public.gs_external_payment_evidence e
      join affected a on a.order_id=e.order_id),
   (select count(*) from public.gs_owner_guest_offers g
      join affected a on a.order_id=g.order_id
      where g.status in ('pending','verified')),
   (select count(*) from public.gs_table_bill_transfer_request_items ri
      join public.gs_table_bill_transfer_request_items other_ri
        on other_ri.order_item_id=ri.order_item_id
       and other_ri.transfer_request_id<>ri.transfer_request_id
      join public.gs_table_bill_transfer_requests other_req
        on other_req.id=other_ri.transfer_request_id
      where ri.transfer_request_id=p_request_id
        and other_req.status in ('pending','approved','applied'))
 into v_items,v_invalid,v_total,v_orders,v_cash,v_ledger,
      v_external,v_offers,v_overlap;

 if v_req.status<>'pending' then
   v_blockers:=array_append(v_blockers,'request_not_pending'); end if;
 if v_source.id is null or v_source.status<>'active' then
   v_blockers:=array_append(v_blockers,'source_visit_not_active'); end if;
 if v_dest.id is null or v_dest.status<>'active' then
   v_blockers:=array_append(v_blockers,'destination_visit_not_active'); end if;
 if v_source.table_id is not distinct from v_dest.table_id
    or v_req.source_visit_id=v_req.destination_visit_id then
   v_blockers:=array_append(v_blockers,'same_source_destination'); end if;
 if v_items=0 then v_blockers:=array_append(v_blockers,'no_items'); end if;
 if v_invalid>0 then v_blockers:=array_append(v_blockers,'invalid_or_changed_items'); end if;
 if v_total<=0 then v_blockers:=array_append(v_blockers,'nonpositive_transfer_value'); end if;
 if v_cash>0 then v_blockers:=array_append(v_blockers,'cash_allocation_required'); end if;
 if v_ledger>0 then v_blockers:=array_append(v_blockers,'ledger_allocation_required'); end if;
 if v_external>0 then v_blockers:=array_append(v_blockers,'external_evidence_review_required'); end if;
 if v_offers>0 then v_blockers:=array_append(v_blockers,'owner_offer_review_required'); end if;
 if v_overlap>0 then v_blockers:=array_append(v_blockers,'overlapping_transfer_request'); end if;
 if exists(select 1 from public.gs_cafe_tables t
   where t.id in (v_source.table_id,v_dest.table_id)
     and (not t.occupied or t.cleaning_needed)) then
   v_blockers:=array_append(v_blockers,'table_unavailable'); end if;
 return query select v_req.id,v_req.status,
  coalesce(v_source.status='active',false),
  coalesce(v_dest.status='active',false),
  coalesce(v_source.table_id<>v_dest.table_id,false),
  v_orders,v_items,v_total,v_invalid,v_cash,v_ledger,v_external,
  v_offers,v_overlap,cardinality(v_blockers)=0,false,v_blockers;
end; $$;
revoke all on function public.gs_validate_table_bill_transfer_request(bigint)
 from public,anon;
grant execute on function public.gs_validate_table_bill_transfer_request(bigint)
 to authenticated;
