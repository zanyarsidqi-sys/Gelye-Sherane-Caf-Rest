-- Run against STAGING before deploying the credit journal guard migration.
-- Read-only diagnostics: any nonzero count must be investigated, not automatically repaired.
select 'charge_without_source_request' as issue,count(*) as affected_rows
from public.gs_credit_account_journal where event_kind='charge' and source_request_id is null
union all
select 'charge_nonpositive_movement',count(*) from public.gs_credit_account_journal
where event_kind='charge' and delta_outstanding_iqd<=0
union all
select 'repayment_nonnegative_movement',count(*) from public.gs_credit_account_journal
where event_kind='repayment' and delta_outstanding_iqd>=0
union all
select 'invalid_idempotency_key',count(*) from public.gs_credit_account_journal
where external_idempotency_key is null or length(btrim(external_idempotency_key)) not between 12 and 200
or external_idempotency_key<>btrim(external_idempotency_key)
union all
select 'duplicate_charge_source_request',count(*) from (
 select source_request_id from public.gs_credit_account_journal
 where event_kind='charge' and source_request_id is not null
 group by source_request_id having count(*)>1) conflicts;
