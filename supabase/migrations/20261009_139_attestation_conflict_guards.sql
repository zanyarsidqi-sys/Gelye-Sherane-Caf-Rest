-- Upgrade 139: prevent mutually contradictory finance attestations.
-- Both settlement types share the same order lock used by payment writers.
create or replace function public.gs_reject_conflicting_settlement_attestation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.gs_orders where id=new.order_id for update;
 if not found then raise exception 'Order not found';end if;
 if TG_TABLE_NAME='gs_mixed_payment_settlement_attestations' then
  if exists(select 1 from public.gs_cash_only_settlement_attestations
    where order_id=new.order_id) then
   raise exception 'Order already has cash-only settlement attestation';
  end if;
 elsif TG_TABLE_NAME='gs_cash_only_settlement_attestations' then
  if exists(select 1 from public.gs_mixed_payment_settlement_attestations
    where order_id=new.order_id) then
   raise exception 'Order already has mixed-payment settlement attestation';
  end if;
 else raise exception 'Unsupported attestation source';end if;
 return new;
end; $$;
drop trigger if exists gs_reject_conflicting_mixed_attestation
 on public.gs_mixed_payment_settlement_attestations;
create trigger gs_reject_conflicting_mixed_attestation
 before insert on public.gs_mixed_payment_settlement_attestations
 for each row execute function public.gs_reject_conflicting_settlement_attestation();
drop trigger if exists gs_reject_conflicting_cash_attestation
 on public.gs_cash_only_settlement_attestations;
create trigger gs_reject_conflicting_cash_attestation
 before insert on public.gs_cash_only_settlement_attestations
 for each row execute function public.gs_reject_conflicting_settlement_attestation();

-- Existing inconsistent records must be investigated, not auto-deleted.
do $$
begin
 if exists(select 1 from public.gs_cash_only_settlement_attestations c
 join public.gs_mixed_payment_settlement_attestations m on m.order_id=c.order_id)
 then raise exception 'Existing contradictory finance attestations require review';
 end if;
end $$;
