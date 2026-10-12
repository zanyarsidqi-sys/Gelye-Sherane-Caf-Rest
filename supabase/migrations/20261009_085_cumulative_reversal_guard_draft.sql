-- Upgrade 85 (DRAFT): cumulative refund/reversal guard.
-- The ledger remains closed to client INSERTs; this protects trusted future writers.
create or replace function public.gs_validate_payment_ledger_reversal()
returns trigger language plpgsql security definer set search_path='' as $$
declare
 v_original public.gs_unified_payment_ledger%rowtype;
 v_used bigint;
begin
 if new.entry_type in ('refund','reversal') then
  if new.original_entry_id is null then
   raise exception 'Refund/reversal requires an original ledger entry';
  end if;
  if new.original_entry_id = new.id then
   raise exception 'Ledger entry cannot reverse itself';
  end if;
  -- Lock the original entry to serialize competing reversals of the same payment.
  -- Do not use FOR SHARE: it permits concurrent overspending.
  select * into v_original from public.gs_unified_payment_ledger
   where id=new.original_entry_id for update;
  if not found then raise exception 'Original payment entry not found'; end if;
  if v_original.order_id is distinct from new.order_id then
   raise exception 'Reversal order mismatch';
  end if;
  if v_original.direction <> 'credit' or
    v_original.entry_type in ('refund','reversal') then
   raise exception 'Only original credit payments may be reversed';
  end if;
  select coalesce(sum(amount_iqd),0)::bigint into v_used
   from public.gs_unified_payment_ledger
   where original_entry_id=v_original.id and direction='debit'
     and entry_type in ('refund','reversal');
  if v_used + new.amount_iqd > v_original.amount_iqd then
   raise exception 'Cumulative refunds/reversals exceed original payment';
  end if;
 elsif new.original_entry_id is not null then
  raise exception 'Only refunds/reversals can reference an original entry';
 end if;
 return new;
end; $$;
revoke all on function public.gs_validate_payment_ledger_reversal()
 from public,anon,authenticated;
-- Existing BEFORE INSERT trigger from Upgrade 84 invokes this replacement.
-- Note: test concurrency under supported isolation levels in staging;
-- no refund-posting API or provider refund has been implemented.
