-- Upgrade 377: line-level finance audit; no unified invoice/payment posting.
create or replace function public.gs_staff_motel_food_finance_line_audit(p_invoice_id uuid)
returns table(source_order_id uuid,source_ledger_id uuid,reservation_id uuid,guest_session_id uuid,room_id uuid,registered_iqd bigint,ledger_iqd bigint,order_iqd bigint,line_status text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel Orders and Invoices & Payments viewing permissions required';
 end if;
 if not exists(select 1 from public.gs_motel_food_invoice_register h where h.id=p_invoice_id) then
  raise exception 'Food register not found';
 end if;
 return query
 select l.source_order_id,l.source_ledger_id,l.reservation_id,h.guest_session_id,h.room_id,
 l.amount_iqd,b.amount_iqd,o.total_iqd,
 case when b.id is null or o.id is null or r.id is null then 'missing_source'
      when b.guest_session_id is distinct from h.guest_session_id
        or o.guest_session_id is distinct from h.guest_session_id
        or r.guest_session_id is distinct from h.guest_session_id
        or b.room_id is distinct from h.room_id
        or o.room_id is distinct from h.room_id
        or r.room_id is distinct from h.room_id then 'guest_room_mismatch'
      when b.request_id is distinct from l.source_order_id
        or r.source_order_id is distinct from l.source_order_id
        or r.source_ledger_id is distinct from l.source_ledger_id then 'source_mismatch'
      when b.amount_iqd is distinct from l.amount_iqd
        or o.total_iqd is distinct from l.amount_iqd
        or r.amount_iqd is distinct from l.amount_iqd then 'amount_mismatch'
      when o.status is distinct from 'delivered' then 'order_not_delivered'
      else 'matched' end::text
 from public.gs_motel_food_invoice_register_lines l
 join public.gs_motel_food_invoice_register h on h.id=l.invoice_id
 left join public.gs_motel_food_billing_ledger b on b.id=l.source_ledger_id
 left join public.gs_motel_guest_food_requests o on o.id=l.source_order_id
 left join public.gs_motel_food_invoice_source_reservations r on r.id=l.reservation_id
 where l.invoice_id=p_invoice_id
 order by l.source_order_id;
end; $$;
revoke all on function public.gs_staff_motel_food_finance_line_audit(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_finance_line_audit(uuid) to authenticated;
