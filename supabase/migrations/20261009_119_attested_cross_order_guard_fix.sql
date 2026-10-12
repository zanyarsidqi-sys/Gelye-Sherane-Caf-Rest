-- Upgrade 119: fix cross-order mutation race in attested-order guard.
-- Upgrade 114 locked only the destination order during order-item moves,
-- permitting a concurrent attestation on the source order to race the move.
create or replace function public.gs_protect_cash_attested_order()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_old_order bigint;v_new_order bigint;v_order bigint;
begin
 if TG_TABLE_NAME='gs_orders' then
  v_old_order:=case when TG_OP in ('UPDATE','DELETE') then old.id else null end;
  v_new_order:=case when TG_OP in ('INSERT','UPDATE') then new.id else null end;
 elsif TG_TABLE_NAME in ('gs_order_items','gs_cash_payments',
   'gs_unified_payment_ledger','gs_cash_correction_postings',
   'gs_external_payment_evidence','gs_owner_guest_offers') then
  v_old_order:=case when TG_OP in ('UPDATE','DELETE') then old.order_id else null end;
  v_new_order:=case when TG_OP in ('INSERT','UPDATE') then new.order_id else null end;
 else
  raise exception 'Unsupported settlement guard source';
 end if;
 if v_old_order is null and v_new_order is null then
  raise exception 'Financial mutation missing parent order';
 end if;
 -- Lock both source and destination parents in stable order. On gs_orders,
 -- the parent row is already being modified, so do not self-lock.
 if TG_TABLE_NAME<>'gs_orders' then
  for v_order in
   select distinct id from unnest(array[v_old_order,v_new_order]) as id
   where id is not null order by id
  loop
   perform 1 from public.gs_orders where id=v_order for update;
   if not found then raise exception 'Parent order not found';end if;
  end loop;
 end if;
 if exists(select 1 from public.gs_cash_only_settlement_attestations a
  where a.order_id in (v_old_order,v_new_order)) then
  raise exception using errcode='P0001',
   message='Cannot mutate a cash-settlement attested order';
 end if;
 if TG_OP='DELETE' then return old;end if;
 return new;
end; $$;
revoke all on function public.gs_protect_cash_attested_order()
 from public,anon,authenticated;
-- Existing triggers installed by Upgrade 114 use this replaced function.
