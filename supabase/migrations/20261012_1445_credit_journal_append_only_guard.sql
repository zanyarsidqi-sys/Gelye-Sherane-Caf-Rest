-- Credit journal posting safety rails for Standing Cash / Pending Payment.
-- No new payment posting API, no debit confirmation, no certified totals.
-- Deploy only after running diagnostics/credit_journal_predeployment.sql in staging.
create or replace function public.gs_financial_credit_journal_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op in ('UPDATE','DELETE') then
  raise exception 'Credit journal is append-only; corrections require a separately authorized reversal event' using errcode='42501';
 end if;
 if new.event_kind='charge' then
  if new.source_request_id is null or new.delta_outstanding_iqd<=0 then
   raise exception 'Charge requires a source verification request and positive outstanding movement' using errcode='22023';
  end if;
 elsif new.event_kind='repayment' then
  if new.delta_outstanding_iqd>=0 then
   raise exception 'Repayment must reduce outstanding credit' using errcode='22023';
  end if;
 end if;
 if new.external_idempotency_key is null or length(btrim(new.external_idempotency_key)) not between 12 and 200
    or new.external_idempotency_key <> btrim(new.external_idempotency_key) then
  raise exception 'A stable, normalized credit journal idempotency key is required' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function public.gs_financial_credit_journal_guard() from public,anon,authenticated;
drop trigger if exists gs_financial_credit_journal_guard_trg on public.gs_credit_account_journal;
create trigger gs_financial_credit_journal_guard_trg
 before insert or update or delete on public.gs_credit_account_journal
 for each row execute function public.gs_financial_credit_journal_guard();
