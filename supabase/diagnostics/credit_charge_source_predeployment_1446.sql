-- Read-only staging diagnostic. Inspect all results before deployment; no corrections are made.
-- Conflicting crosswalk evidence prevents unique-index installation.
select 'active_order_conflict' as issue,cafe_order_id::text as source,count(*) as occurrences
from public.gs_financial_crosswalk_evidence where review_state<>'rejected'
group by cafe_order_id having count(*)>1
union all
select 'active_invoice_conflict',motel_invoice_id::text,count(*)
from public.gs_financial_crosswalk_evidence where review_state<>'rejected'
group by motel_invoice_id having count(*)>1;
-- Previously recorded charges failing newly required source, account and invoice links.
select j.id,j.source_request_id,j.account_id,j.delta_outstanding_iqd,
 case when q.id is null then 'missing_request'
      when q.status<>'pending' or q.amount_iqd<>j.delta_outstanding_iqd then 'request_mismatch'
      when d.id is null or d.method<>'credit' or d.amount_iqd<>q.amount_iqd then 'intent_mismatch'
      when f.id is null or f.total_iqd<>q.amount_iqd then 'invoice_mismatch'
      when l.registry_id is null or l.link_status<>'verified' or l.account_id<>j.account_id then 'unverified_registry_link'
      when a.id is null or a.account_status<>'active' then 'inactive_account'
      when c.id is null or c.verification_status<>'verified' then 'unverified_customer'
      else 'source_fields_match_review_balance_separately' end as diagnostic
from public.gs_credit_account_journal j
left join public.gs_motel_credit_verification_requests q on q.id=j.source_request_id
left join public.gs_motel_food_payment_intent_drafts d on d.id=q.intent_id
left join public.gs_motel_food_finance_invoices f on f.id=d.finance_invoice_id
left join public.gs_credit_account_registry_links l on l.registry_id=q.registry_id
left join public.gs_credit_accounts a on a.id=j.account_id
left join public.gs_credit_customers c on c.id=a.customer_id
where j.event_kind='charge';
