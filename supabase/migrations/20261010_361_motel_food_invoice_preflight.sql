-- Upgrade 361: invoice-link preflight only; never writes financial records.
-- Existing staging ledger forbids invoice_id; no unsafe linkage is attempted.
create or replace function public.gs_staff_motel_food_invoice_preflight()
returns table(request_id uuid, room_label text, amount_iqd bigint,
 order_status text, ledger_status text, line_total_iqd numeric,
 eligible_for_future_invoice boolean, blockers text[])
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 return query
 select l.request_id, r.room_label, l.amount_iqd, o.status, l.payment_status,
        coalesce(x.lines,0),
        (o.status='delivered' and o.delivered_at is not null
         and coalesce(x.lines,0)=l.amount_iqd and o.total_iqd=l.amount_iqd
         and l.payment_status='unpaid' and l.invoice_id is null),
        array_remove(array[
          case when o.status<>'delivered' then 'order_not_delivered' end,
          case when o.delivered_at is null then 'missing_delivery_timestamp' end,
          case when coalesce(x.lines,0)<>l.amount_iqd or o.total_iqd<>l.amount_iqd then 'amount_mismatch' end,
          case when l.payment_status<>'unpaid' then 'payment_status_not_unpaid' end,
          case when l.invoice_id is not null then 'already_linked' end
        ]::text[],null::text)
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 join public.gs_motel_room_qr r on r.id=l.room_id
 left join lateral (select sum(i.line_total_iqd)::numeric as lines
    from public.gs_motel_guest_food_request_items i where i.request_id=l.request_id) x on true
 order by l.posted_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_preflight() from public;
grant execute on function public.gs_staff_motel_food_invoice_preflight() to authenticated;
