-- Upgrade 1251: read-only, permission-gated Finance invoice retrieval.
-- Existing motel finance postings are UNPAID, not finalized. Never treat them
-- as a settled invoice or silently generate an official receipt.
create or replace function public.gs_staff_read_motel_finance_print_snapshot(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_invoice public.gs_motel_food_finance_invoices%rowtype;
        v_lines jsonb; v_count integer; v_total bigint;
begin
  if auth.uid() is null
     or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
     or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
    raise exception 'Finance and motel viewing permissions required' using errcode='42501';
  end if;
  if p_invoice_id is null then raise exception 'Invoice ID required'; end if;
  select * into v_invoice from public.gs_motel_food_finance_invoices
    where id=p_invoice_id;
  if not found then raise exception 'Invoice unavailable'; end if;
  select count(*)::integer, coalesce(sum(l.amount_iqd),0)::bigint,
    coalesce(jsonb_agg(jsonb_build_object(
      'description','Motel food order ' || l.source_order_id::text,
      'quantity',1,'total_minor',l.amount_iqd)
      order by l.id), '[]'::jsonb)
    into v_count,v_total,v_lines
    from public.gs_motel_food_finance_invoice_lines l
    where l.finance_invoice_id=v_invoice.id;
  if v_count <> v_invoice.source_count or v_total <> v_invoice.total_iqd
     or v_count=0 then raise exception 'Finance invoice lines do not reconcile'; end if;
  return jsonb_build_object(
    'invoice_id',v_invoice.id::text,
    'invoice_number',v_invoice.id::text,
    'issued_at',v_invoice.posted_at,
    'currency','IQD', 'payment_status',v_invoice.payment_status,
    'total_minor',v_invoice.total_iqd, 'lines',v_lines,
    'is_finalized',false,
    'source','motel_food_finance_posting',
    'warning','Posted/unpaid motel-food invoice is not finalized for printing');
end; $$;
revoke all on function public.gs_staff_read_motel_finance_print_snapshot(uuid) from public,anon;
grant execute on function public.gs_staff_read_motel_finance_print_snapshot(uuid) to authenticated;
