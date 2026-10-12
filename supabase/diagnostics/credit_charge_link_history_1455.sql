-- Upgrade 1455: run on staging before enabling posting; never backfill automatically.
-- Existing journal charges predating the link trigger need manual source review.
select j.id as journal_id, j.source_request_id, j.delta_outstanding_iqd,
       d.finance_invoice_id, l.id as linked_record_id
from public.gs_credit_account_journal j
left join public.gs_motel_credit_verification_requests r on r.id=j.source_request_id
left join public.gs_motel_food_payment_intent_drafts d on d.id=r.intent_id
left join public.gs_financial_credit_invoice_charge_links l on l.credit_journal_id=j.id
where j.event_kind='charge' and (l.id is null or d.finance_invoice_id is distinct from l.finance_invoice_id
 or j.delta_outstanding_iqd is distinct from l.amount_iqd);
