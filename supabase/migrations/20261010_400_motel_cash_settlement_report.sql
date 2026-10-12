-- Upgrade 400: authorized, read-only motel cash settlement reconciliation.
create or replace function public.gs_staff_motel_cash_settlement_report(p_limit integer default 100)
returns table(
 settlement_id uuid, finance_invoice_id uuid, intent_id uuid,
 amount_iqd bigint, invoice_total_iqd bigint, payment_status text,
 receipt_reference text, settled_by uuid, settled_at timestamptz,
 reconciliation_status text
)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Authorized finance viewer required';
 end if;
 if p_limit is null or p_limit < 1 or p_limit > 500 then
  raise exception 'Report limit must be between 1 and 500';
 end if;
 return query
 select s.id,s.finance_invoice_id,s.intent_id,s.amount_iqd,f.total_iqd,
        f.payment_status,s.receipt_reference,s.settled_by,s.settled_at,
        case
          when f.payment_status is distinct from 'paid_cash' then 'invoice_not_paid'
          when f.total_iqd is distinct from s.amount_iqd then 'amount_mismatch'
          when d.id is null or d.finance_invoice_id is distinct from s.finance_invoice_id
               or d.method is distinct from 'cash'
               or d.amount_iqd is distinct from s.amount_iqd then 'draft_mismatch'
          when r.id is null or r.id is distinct from s.review_id
               or r.intent_id is distinct from s.intent_id
               or r.cash_receipt_reference is distinct from s.receipt_reference
               or r.review_status is distinct from 'cash_received_pending_settlement'
               then 'receipt_mismatch'
          else 'matched'
        end::text
 from public.gs_motel_food_cash_settlements s
 join public.gs_motel_food_finance_invoices f on f.id=s.finance_invoice_id
 left join public.gs_motel_food_payment_intent_drafts d on d.id=s.intent_id
 left join public.gs_motel_cash_confirmation_reviews r on r.id=s.review_id
 order by s.settled_at desc,s.id desc limit p_limit;
end; $$;
revoke all on function public.gs_staff_motel_cash_settlement_report(integer) from public,anon;
grant execute on function public.gs_staff_motel_cash_settlement_report(integer) to authenticated;
