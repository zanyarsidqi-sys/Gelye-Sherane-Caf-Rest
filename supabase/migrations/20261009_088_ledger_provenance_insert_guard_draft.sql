-- Upgrade 88 (DRAFT): fail-closed payment ledger provenance INSERT guard.
-- Structural validation is NOT proof of payment or provider verification.
create or replace function public.gs_guard_payment_ledger_insert_provenance()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.posted_by is null then
   raise exception 'Payment ledger posting actor is required';
 end if;
 if length(btrim(coalesce(new.source_system,'')))=0 or
    length(btrim(coalesce(new.source_reference,'')))=0 then
   raise exception 'Payment source and reference must not be blank';
 end if;
 if new.verified_at is null or new.verified_at > statement_timestamp() then
   raise exception 'Payment verification timestamp cannot be missing or in the future';
 end if;
 if new.posted_at is null or new.posted_at > statement_timestamp() then
   raise exception 'Payment posting timestamp cannot be missing or in the future';
 end if;
 if new.verified_at > new.posted_at then
   raise exception 'Payment cannot be verified after its posting timestamp';
 end if;
 if new.entry_type='owner_waiver' then
   raise exception 'Owner waiver posting disabled until verified approval and allocation are implemented';
 end if;
 if new.entry_type in ('card','online','credit') then
   raise exception 'External/credit posting disabled until trusted provider verification is implemented';
 end if;
 if new.entry_type in ('refund','reversal') then
   raise exception 'Refund posting disabled until trusted refund execution and allocation are implemented';
 end if;
 -- Cash posting remains limited to trusted database writers by existing
 -- table grants; this guard alone cannot authenticate physical cash received.
 return new;
end; $$;
revoke all on function public.gs_guard_payment_ledger_insert_provenance()
 from public,anon,authenticated;
drop trigger if exists gs_guard_payment_ledger_insert_provenance
 on public.gs_unified_payment_ledger;
create trigger gs_guard_payment_ledger_insert_provenance
 before insert on public.gs_unified_payment_ledger
 for each row execute function public.gs_guard_payment_ledger_insert_provenance();
-- No client INSERT grants or posting RPC are created.
