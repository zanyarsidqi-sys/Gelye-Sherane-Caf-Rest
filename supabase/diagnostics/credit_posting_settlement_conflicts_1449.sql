-- Read-only predeployment audit; review results before enabling posting.
select f.id as invoice_id, count(distinct cash.id) as cash_settlements,
       count(distinct j.id) as credit_charges
from public.gs_motel_food_finance_invoices f
left join public.gs_motel_food_cash_settlements cash on cash.finance_invoice_id=f.id
left join public.gs_motel_food_payment_intent_drafts d on d.finance_invoice_id=f.id
left join public.gs_motel_credit_verification_requests q on q.intent_id=d.id
left join public.gs_credit_account_journal j on j.source_request_id=q.id and j.event_kind='charge'
group by f.id
having count(distinct cash.id)>0 and count(distinct j.id)>0;

select a.id as account_id,a.outstanding_iqd,
 (select j.outstanding_after_iqd from public.gs_credit_account_journal j
  where j.account_id=a.id order by j.created_at desc,j.id desc limit 1) as latest_journal_iqd
from public.gs_credit_accounts a
where a.outstanding_iqd is distinct from
 coalesce((select j.outstanding_after_iqd from public.gs_credit_account_journal j
  where j.account_id=a.id order by j.created_at desc,j.id desc limit 1),0);
