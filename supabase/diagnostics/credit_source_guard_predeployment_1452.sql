-- Upgrade 1452: read-only staging diagnostic. Run before migration; investigate all rows.
-- Does not authorize settlement or certify balances.
select f.id as invoice_id, f.total_iqd, f.source_count,
 (select count(*) from public.gs_motel_food_finance_invoice_lines l where l.finance_invoice_id=f.id) as actual_source_count,
 (select coalesce(sum(l.amount_iqd),0) from public.gs_motel_food_finance_invoice_lines l where l.finance_invoice_id=f.id) as actual_source_total,
 (select count(*) from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=f.id) as cash_settlement_count,
 (select count(*) from public.gs_motel_food_payment_intent_drafts d where d.finance_invoice_id=f.id) as draft_count
from public.gs_motel_food_finance_invoices f
where f.total_iqd<=0 or f.source_count<=0
 or f.source_count<>(select count(*) from public.gs_motel_food_finance_invoice_lines l where l.finance_invoice_id=f.id)
 or f.total_iqd<>(select coalesce(sum(l.amount_iqd),0) from public.gs_motel_food_finance_invoice_lines l where l.finance_invoice_id=f.id)
 or (select count(*) from public.gs_motel_food_cash_settlements c where c.finance_invoice_id=f.id)>0
 or (select count(*) from public.gs_motel_food_payment_intent_drafts d where d.finance_invoice_id=f.id)>1;
