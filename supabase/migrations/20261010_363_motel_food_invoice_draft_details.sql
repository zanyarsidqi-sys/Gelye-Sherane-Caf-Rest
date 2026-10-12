-- Upgrade 363: employee-only itemized food invoice draft review.
-- Read only: no invoice, settlement, or credit transaction is posted.
create or replace function public.gs_staff_motel_food_invoice_draft_details(p_guest_session_id uuid)
returns table(request_id uuid, delivered_at timestamptz, product_name text,
 quantity integer, unit_price_iqd numeric, line_total_iqd numeric,
 order_total_iqd numeric, ledger_amount_iqd bigint, eligible boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 return query
 select o.id, o.delivered_at, i.product_name::text, i.quantity::integer,
        i.unit_price_iqd::numeric, i.line_total_iqd::numeric,
        o.total_iqd::numeric, l.amount_iqd,
        (o.status='delivered' and o.delivered_at is not null
         and o.total_iqd=l.amount_iqd and l.payment_status='unpaid'
         and l.invoice_id is null and
         (select coalesce(sum(x.line_total_iqd),0)
          from public.gs_motel_guest_food_request_items x where x.request_id=o.id)=l.amount_iqd)
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 join public.gs_motel_guest_food_request_items i on i.request_id=o.id
 where l.guest_session_id=p_guest_session_id and o.guest_session_id=p_guest_session_id
 order by o.delivered_at desc, o.id, i.product_name
 limit 500;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_draft_details(uuid) from public;
grant execute on function public.gs_staff_motel_food_invoice_draft_details(uuid) to authenticated;
