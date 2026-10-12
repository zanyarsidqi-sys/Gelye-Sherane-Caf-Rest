-- Upgrade 378: comprehensive read-only register readiness. No payment/invoice posting.
create or replace function public.gs_staff_motel_food_invoice_readiness(p_invoice_id uuid)
returns table(invoice_id uuid, expected_lines integer, actual_lines bigint, expected_iqd bigint, actual_iqd numeric, matched_lines bigint, blocked_lines bigint, readiness_status text)
language plpgsql security definer set search_path = '' as $$
declare v_header public.gs_motel_food_invoice_register%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel Orders and Invoices & Payments viewing permissions required';
 end if;
 select * into v_header from public.gs_motel_food_invoice_register h where h.id=p_invoice_id;
 if not found then raise exception 'Food register not found'; end if;
 return query
 with audit as (
   select a.line_status from public.gs_staff_motel_food_finance_line_audit(p_invoice_id) a
 ), totals as (
   select count(*)::bigint as line_count,
          count(*) filter(where line_status='matched')::bigint as good_count,
          count(*) filter(where line_status<>'matched')::bigint as bad_count
   from audit
 ), amounts as (
   select coalesce(sum(l.amount_iqd),0)::numeric as line_total
   from public.gs_motel_food_invoice_register_lines l where l.invoice_id=p_invoice_id
 )
 select v_header.id,v_header.source_count,t.line_count,v_header.total_iqd,a.line_total,
 t.good_count,t.bad_count,
 case when t.line_count=v_header.source_count and a.line_total=v_header.total_iqd
       and t.bad_count=0 and t.good_count=v_header.source_count then 'source_verified'
      else 'blocked_reconciliation_required' end::text
 from totals t cross join amounts a;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_invoice_readiness(uuid) to authenticated;
