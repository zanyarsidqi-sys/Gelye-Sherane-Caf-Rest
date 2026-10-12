-- Upgrade 391: auditable payment draft history. Read-only; no settlement.
create or replace function public.gs_staff_motel_food_payment_draft_history(p_finance_invoice_id uuid)
returns table(intent_id uuid, method text, amount_iqd bigint, status text,
 created_at timestamptz, created_by uuid, cancelled_at timestamptz,
 cancelled_by uuid, cancellation_reason text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 if not exists (select 1 from public.gs_motel_food_finance_invoices f
   where f.id=p_finance_invoice_id) then
  raise exception 'Finance invoice not found';
 end if;
 return query
 select d.id,d.method,d.amount_iqd,d.status,d.created_at,d.created_by,
 d.cancelled_at,d.cancelled_by,d.cancellation_reason
 from public.gs_motel_food_payment_intent_drafts d
 where d.finance_invoice_id=p_finance_invoice_id
 order by d.created_at desc,d.id desc limit 100;
end; $$;
revoke all on function public.gs_staff_motel_food_payment_draft_history(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_payment_draft_history(uuid) to authenticated;
