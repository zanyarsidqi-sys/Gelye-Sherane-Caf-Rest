-- Upgrade 376: read-only cross-module handoff; does not create financial postings.
create or replace function public.gs_staff_motel_food_finance_handoff()
returns table(invoice_id uuid,guest_session_id uuid,room_id uuid,total_iqd bigint,source_count integer,posted_at timestamptz,registered_line_count bigint,registered_line_total_iqd numeric,integrity_status text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
  or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
  or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel Orders and Invoices & Payments viewing permissions required';
 end if;
 return query
 select h.id,h.guest_session_id,h.room_id,h.total_iqd,h.source_count,h.posted_at,
  count(l.id)::bigint,coalesce(sum(l.amount_iqd),0)::numeric,
  case when count(l.id)=h.source_count and coalesce(sum(l.amount_iqd),0)=h.total_iqd
    and count(distinct l.source_order_id)=h.source_count
    and count(distinct l.source_ledger_id)=h.source_count
    and count(distinct l.reservation_id)=h.source_count
    then 'matched' else 'requires_review' end::text
 from public.gs_motel_food_invoice_register h
 left join public.gs_motel_food_invoice_register_lines l on l.invoice_id=h.id
 group by h.id,h.guest_session_id,h.room_id,h.total_iqd,h.source_count,h.posted_at
 order by h.posted_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_finance_handoff() from public,anon;
grant execute on function public.gs_staff_motel_food_finance_handoff() to authenticated;
