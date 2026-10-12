-- Read-only, server-authorized cash receipt listing; no synthetic payment receipts.
create or replace function public.gs_cash_receipts_for_order(p_order_id bigint)
returns table(receipt_id bigint, order_id bigint, amount_iqd bigint, reference uuid, collected_by uuid, collected_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (public.gs_can_access('invoices_payments') or public.gs_can_access('payments_management')) then
    raise exception 'Not authorized to view cash receipts';
  end if;
  if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order ID'; end if;
  return query select p.id, p.order_id, p.amount_iqd, p.reference, p.collected_by, p.collected_at
    from public.gs_cash_payments p where p.order_id = p_order_id order by p.collected_at desc, p.id desc;
end;
$$;
revoke all on function public.gs_cash_receipts_for_order(bigint) from public, anon;
grant execute on function public.gs_cash_receipts_for_order(bigint) to authenticated;
