-- Upgrade 1457: enforce charge-journal balance consistency at the write boundary.
-- Prevent privileged direct journal inserts that skip the account balance update.
-- This does not settle an invoice or certify Dashboard amounts.
create or replace function public.gs_financial_credit_charge_balance_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
 v_account public.gs_credit_accounts%rowtype;
 v_existing_count bigint;
begin
 if new.event_kind <> 'charge' then return new; end if;
 if new.delta_outstanding_iqd <= 0 or new.outstanding_after_iqd < new.delta_outstanding_iqd then
  raise exception 'Positive credit charge and nonnegative prior balance required' using errcode='22023';
 end if;
 -- FOR SHARE conflicts with concurrent account UPDATE and waits for its transaction.
 select * into v_account from public.gs_credit_accounts
  where id = new.account_id for share;
 if not found or v_account.outstanding_iqd is distinct from new.outstanding_after_iqd then
  raise exception 'Credit journal charge must match atomically updated account balance' using errcode='23514';
 end if;
 -- A duplicate request is also protected by a partial unique index.
 select count(*) into v_existing_count from public.gs_credit_account_journal
  where source_request_id = new.source_request_id and event_kind='charge';
 if v_existing_count <> 0 then
  raise exception 'Credit verification request already charged' using errcode='23505';
 end if;
 return new;
end $$;
revoke all on function public.gs_financial_credit_charge_balance_guard() from public, anon, authenticated;
drop trigger if exists gs_financial_credit_charge_balance_guard_before_insert on public.gs_credit_account_journal;
create trigger gs_financial_credit_charge_balance_guard_before_insert
 before insert on public.gs_credit_account_journal
 for each row execute function public.gs_financial_credit_charge_balance_guard();
