-- Upgrade 386: read-only source-line drilldown for posted motel food finance invoices.
-- This function does not modify financial or payment records.
create or replace function public.gs_staff_motel_food_finance_invoice_line_details(p_finance_invoice_id uuid)
returns table(source_order_id uuid, source_register_line_id uuid, amount_iqd bigint,
 order_amount_iqd bigint, room_id uuid, guest_session_id uuid, order_status text,
 line_status text)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_finance_invoices%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 select * into v from public.gs_motel_food_finance_invoices f where f.id=p_finance_invoice_id;
 if not found then raise exception 'Finance invoice not found'; end if;
 return query
 select l.source_order_id,l.source_register_line_id,l.amount_iqd,o.total_iqd,
        o.room_id,o.guest_session_id,o.status,
        case when r.id is null or r.invoice_id is distinct from v.food_invoice_id
              or r.source_order_id is distinct from l.source_order_id
              or r.amount_iqd is distinct from l.amount_iqd
              or o.id is null or o.room_id is distinct from v.room_id
              or o.guest_session_id is distinct from v.guest_session_id
              or o.status is distinct from 'delivered'
              or o.total_iqd is distinct from l.amount_iqd
          then 'requires_review' else 'matched' end::text
 from public.gs_motel_food_finance_invoice_lines l
 left join public.gs_motel_food_invoice_register_lines r on r.id=l.source_register_line_id
 left join public.gs_motel_guest_food_requests o on o.id=l.source_order_id
 where l.finance_invoice_id=p_finance_invoice_id
 order by l.source_order_id;
end; $$;
revoke all on function public.gs_staff_motel_food_finance_invoice_line_details(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_finance_invoice_line_details(uuid) to authenticated;
