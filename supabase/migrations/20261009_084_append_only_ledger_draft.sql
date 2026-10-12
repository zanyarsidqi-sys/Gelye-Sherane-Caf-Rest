-- Upgrade 84: append-only unified payment ledger safeguard (DRAFT).
-- A payment ledger is an accounting record, not an editable order note.
-- Corrections must be posted as new reversal/refund entries with references.
create or replace function public.gs_enforce_append_only_payment_ledger()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 raise exception using
  errcode='P0001',
  message='Unified payment ledger entries are append-only; post an audited reversal instead';
end; $$;
revoke all on function public.gs_enforce_append_only_payment_ledger()
 from public,anon,authenticated;
drop trigger if exists gs_append_only_payment_ledger
 on public.gs_unified_payment_ledger;
create trigger gs_append_only_payment_ledger
 before update or delete on public.gs_unified_payment_ledger
 for each row execute function public.gs_enforce_append_only_payment_ledger();

-- Reversal references must stay within the same order and be opposite-side
-- accounting entries. This is structural integrity only, NOT payment verification.
create or replace function public.gs_validate_payment_ledger_reversal()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_original public.gs_unified_payment_ledger%rowtype;
begin
 if new.entry_type in ('refund','reversal') then
  if new.original_entry_id is null then
   raise exception 'Refund/reversal must reference an original ledger entry';
  end if;
  select * into v_original from public.gs_unified_payment_ledger
   where id=new.original_entry_id for share;
  if not found then raise exception 'Original ledger entry missing'; end if;
  if v_original.order_id is distinct from new.order_id then
   raise exception 'Refund/reversal cannot reference a different order';
  end if;
  if v_original.direction<>'credit' then
   raise exception 'Refund/reversal must reference a credit entry';
  end if;
  if new.amount_iqd>v_original.amount_iqd then
   raise exception 'Single refund/reversal exceeds original entry';
  end if;
  -- The sum of multiple concurrent refunds is NOT certified here.
  -- Actual refund posting remains disabled until serialized allocation exists.
 elsif new.original_entry_id is not null then
  raise exception 'Only refund/reversal entries may reference an original entry';
 end if;
 return new;
end; $$;
revoke all on function public.gs_validate_payment_ledger_reversal()
 from public,anon,authenticated;
drop trigger if exists gs_validate_payment_ledger_reversal
 on public.gs_unified_payment_ledger;
create trigger gs_validate_payment_ledger_reversal
 before insert on public.gs_unified_payment_ledger
 for each row execute function public.gs_validate_payment_ledger_reversal();

-- No client INSERT/UPDATE/DELETE grants. No posting RPC. No table transfer.
-- Administrative backfills must be separately reviewed before deploying.
