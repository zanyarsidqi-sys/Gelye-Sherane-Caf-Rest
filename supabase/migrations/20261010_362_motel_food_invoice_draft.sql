-- Upgrade 362: read-only room food invoice draft, NOT an official invoice.
-- Group by guest stay, never by room alone (which can host sequential guests).
create or replace function public.gs_staff_motel_food_invoice_drafts()
returns table(guest_session_id uuid, room_label text, room_name text,
  delivered_order_count bigint, food_subtotal_iqd numeric,
  eligible_order_count bigint, blocked_order_count bigint)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 return query
 select l.guest_session_id, r.room_label, r.room_name,
        count(*)::bigint, coalesce(sum(l.amount_iqd),0)::numeric,
        count(*) filter (where o.status='delivered' and o.delivered_at is not null
           and o.total_iqd=l.amount_iqd and l.payment_status='unpaid'
           and l.invoice_id is null and
           (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
              where i.request_id=l.request_id)=l.amount_iqd)::bigint,
        count(*) filter (where not (o.status='delivered' and o.delivered_at is not null
           and o.total_iqd=l.amount_iqd and l.payment_status='unpaid'
           and l.invoice_id is null and
           (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
              where i.request_id=l.request_id)=l.amount_iqd))::bigint
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 join public.gs_motel_room_qr r on r.id=l.room_id
 group by l.guest_session_id,r.room_label,r.room_name
 order by r.room_label,l.guest_session_id
 limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_drafts() from public;
grant execute on function public.gs_staff_motel_food_invoice_drafts() to authenticated;
