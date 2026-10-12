-- Read-only readiness audit. Investigate all returned rows before enabling credit charge posting.
select 'credit_request_multiple_per_invoice' as finding, i.finance_invoice_id::text as subject, count(*)::bigint as evidence_count
from public.gs_motel_credit_verification_requests r
join public.gs_motel_food_payment_intent_drafts i on i.id=r.intent_id
where r.status='pending' group by i.finance_invoice_id having count(*)>1
union all
select 'credit_journal_multiple_charges_per_invoice', i.finance_invoice_id::text,count(*)::bigint
from public.gs_credit_account_journal j
join public.gs_motel_credit_verification_requests r on r.id=j.source_request_id
join public.gs_motel_food_payment_intent_drafts i on i.id=r.intent_id
where j.event_kind='charge' group by i.finance_invoice_id having count(*)>1
union all
select 'credit_journal_account_mismatch',j.account_id::text,count(*)::bigint
from public.gs_credit_account_journal j
join public.gs_credit_accounts a on a.id=j.account_id
where j.outstanding_after_iqd>a.credit_limit_iqd
group by j.account_id;
