-- Read-only mapping of numeric café order identities to UUID motel finance invoices.
-- This is source linkage only: NEVER payment or prepaid confirmation.
create or replace function public.gs_financial_order_motel_uuid_links(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_count bigint; v_invoice_count bigint; v_total numeric; v_negative bigint;
 v_conflicts bigint; v_missing bigint; v_links jsonb; v_order_exists boolean;
begin
 if (select auth.uid()) is null
 or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Payments and Motel viewing permissions required' using errcode='42501';
 end if;
 if p_order_id is null or p_order_id <= 0 then
  raise exception 'Positive order ID required' using errcode='22023'; end if;
 select exists(select 1 from public.gs_orders o where o.id=p_order_id)
 into v_order_exists;
 if not v_order_exists then raise exception 'Order not found' using errcode='P0002'; end if;
 select count(*),count(distinct l.finance_invoice_id),coalesce(sum(l.amount_iqd),0),
 count(*) filter(where l.amount_iqd < 0),
 count(*) filter(where r.id is null or r.source_order_id::text is distinct from l.source_order_id::text
 or r.amount_iqd is distinct from l.amount_iqd),
 count(*) filter(where f.id is null)
 into v_count,v_invoice_count,v_total,v_negative,v_conflicts,v_missing
 from public.gs_motel_food_finance_invoice_lines l
 left join public.gs_motel_food_invoice_register_lines r on r.id=l.source_register_line_id
 left join public.gs_motel_food_finance_invoices f on f.id=l.finance_invoice_id
 where l.source_order_id::text=p_order_id::text;
 select coalesce(jsonb_agg(x.obj order by x.invoice_id), '[]'::jsonb) into v_links
 from (select f.id as invoice_id,jsonb_build_object(
 'invoice_id',f.id,'food_invoice_id',f.food_invoice_id,
 'guest_session_id',f.guest_session_id,'room_id',f.room_id,
 'source_line_count',count(l.*),'source_line_total_iqd',sum(l.amount_iqd),
 'invoice_total_iqd',f.total_iqd,'invoice_source_count',f.source_count
 ) as obj
 from public.gs_motel_food_finance_invoice_lines l
 join public.gs_motel_food_finance_invoices f on f.id=l.finance_invoice_id
 where l.source_order_id::text=p_order_id::text
 group by f.id,f.food_invoice_id,f.guest_session_id,f.room_id,f.total_iqd,f.source_count) x;
 return jsonb_build_object('order_id',p_order_id,'motel_source_line_count',v_count,
 'distinct_invoice_count',v_invoice_count,'linked_source_total_iqd',v_total,
 'negative_line_count',v_negative,'register_mismatch_count',v_conflicts,
 'missing_invoice_count',v_missing,'multiple_invoice_collision',v_invoice_count>1,
 'invoice_links',v_links,'prepaid_certified_iqd',null,
 'credit_debit_confirmed',false,'settled_iqd',null,'outstanding_iqd',null,
 'verified_complete',false,'generated_at',now(),
 'warning','Invoice source identity does not establish prepaid, credit debit, or cash settlement.');
end $$;
revoke all on function public.gs_financial_order_motel_uuid_links(bigint) from public,anon;
grant execute on function public.gs_financial_order_motel_uuid_links(bigint) to authenticated;
