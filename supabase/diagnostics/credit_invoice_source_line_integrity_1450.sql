-- Read-only: any returned row blocks rollout until investigated.
select f.id as invoice_id, f.source_count, f.total_iqd,
 count(l.id) as actual_source_lines, coalesce(sum(l.amount_iqd),0) as actual_source_total_iqd
from public.gs_motel_food_finance_invoices f
left join public.gs_motel_food_finance_invoice_lines l on l.finance_invoice_id=f.id
group by f.id
having f.source_count<>count(l.id) or f.total_iqd<>coalesce(sum(l.amount_iqd),0) or f.total_iqd<=0;

select finance_invoice_id,count(*) as payment_intents,
 count(distinct method) as distinct_methods
from public.gs_motel_food_payment_intent_drafts
group by finance_invoice_id having count(*)>1;
