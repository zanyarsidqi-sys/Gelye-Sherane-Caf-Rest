-- Upgrade 1451 read-only deployment checks; investigate results before deploying.
select 'inactive_registry' as issue,q.id as request_id
from public.gs_motel_credit_verification_requests q
join public.gs_motel_credit_barcode_registry r on r.id=q.registry_id
where q.status='pending' and r.account_status<>'active';

select 'registry_account_reference_mismatch' as issue,l.registry_id,l.account_id
from public.gs_credit_account_registry_links l
join public.gs_motel_credit_barcode_registry r on r.id=l.registry_id
join public.gs_credit_accounts a on a.id=l.account_id
where l.link_status='verified' and r.account_reference is distinct from a.account_reference;

select 'ambiguous_latest_journal_balance' as issue,a.id as account_id
from public.gs_credit_accounts a
where exists (select 1 from public.gs_credit_account_journal j
 where j.account_id=a.id and j.created_at=(select max(j2.created_at) from public.gs_credit_account_journal j2 where j2.account_id=a.id)
 and j.outstanding_after_iqd is distinct from a.outstanding_iqd);
