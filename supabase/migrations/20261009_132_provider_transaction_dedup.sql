-- Upgrade 132: prevent a single real provider transaction from being posted
-- more than once under DIFFERENT provider event IDs.
-- Requires cleanup of any pre-existing duplicate provider references before
-- migration; fail closed rather than silently choosing a transaction.
do $$
begin
 if exists (
  select 1 from public.gs_payment_verification_inbox
  where intake_status='verified_by_server'
  group by lower(btrim(provider)), btrim(provider_reference)
  having count(*)>1
 ) then
  raise exception 'Duplicate verified provider transactions exist; investigate before enabling settlement';
 end if;
end $$;

-- Multiple events (e.g. webhook retries) can have different event IDs but
-- must not independently represent a second payment for one transaction.
create unique index if not exists gs_verified_provider_transaction_once
 on public.gs_payment_verification_inbox
 (lower(btrim(provider)),btrim(provider_reference))
 where intake_status='verified_by_server';

-- Payment ledger is append-only. A source event can never create two credits.
do $$
begin
 if exists (
  select 1 from public.gs_unified_payment_ledger
  where source_system='verified_provider_event'
  group by source_reference having count(*)>1
 ) then
  raise exception 'Duplicate verified provider ledger postings exist; investigate before migration';
 end if;
end $$;
create unique index if not exists gs_verified_provider_event_ledger_once
 on public.gs_unified_payment_ledger (source_reference)
 where source_system='verified_provider_event';

-- Do not assume the same provider_reference is globally unique across
-- different providers. Provider and reference form the transaction identity.
-- Verified intake from Upgrade 130 now fails atomically if a different
-- provider event tries to verify the same underlying transaction.
