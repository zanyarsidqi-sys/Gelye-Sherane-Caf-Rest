-- Upgrade 113: an actual, narrowly scoped finance settlement attestation.
-- CASH-ONLY orders with no ledger, correction, transfer, owner or external
-- evidence. This does not enable checkout or certify other payment methods.
create table if not exists public.gs_cash_only_settlement_attestations (
 id bigint generated always as identity primary key,
 order_id bigint not null unique references public.gs_orders(id) on delete restrict,
 table_visit_id bigint not null references public.gs_table_visits(id),
 order_total_iqd bigint not null check(order_total_iqd>0),
 collected_cash_iqd bigint not null check(collected_cash_iqd>0),
 receipt_count bigint not null check(receipt_count>0),
 attested_by uuid not null references auth.users(id),
 attested_at timestamptz not null default now(),
 check(order_total_iqd=collected_cash_iqd)
);
alter table public.gs_cash_only_settlement_attestations enable row level security;
revoke all on public.gs_cash_only_settlement_attestations from public,anon,authenticated;
create or replace function public.gs_block_cash_only_settlement_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Cash-only settlement attestations are immutable'; end; $$;
drop trigger if exists gs_cash_only_settlement_immutable on public.gs_cash_only_settlement_attestations;
create trigger gs_cash_only_settlement_immutable before update or delete
 on public.gs_cash_only_settlement_attestations for each row
 execute function public.gs_block_cash_only_settlement_mutation();

create or replace function public.gs_attest_cash_only_order_settlement(p_order_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype;
 v_total bigint;v_cash bigint;v_receipts bigint;v_existing bigint;
 v_id bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
  or not public.gs_can_access('invoices_payments','can_edit')
  or not exists(select 1 from public.gs_cash_correction_finance_reviewers
    where user_id=auth.uid() and enabled) then
  raise exception 'Provisioned finance reviewer, MFA and edit permission required';
 end if;
 if p_order_id is null then raise exception 'Order required'; end if;
 -- Same order lock as cash-collection writer, so amount is stable here.
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found or v_order.table_visit_id is null or v_order.status='cancelled' then
  raise exception 'Eligible table order not found'; end if;
 select id into v_existing from public.gs_cash_only_settlement_attestations
  where order_id=p_order_id;
 if found then return v_existing; end if;
 if not exists(select 1 from public.gs_table_visits v
    where v.id=v_order.table_visit_id and v.status in ('active','cleaning')) then
  raise exception 'No valid open table visit'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
  from public.gs_order_items where order_id=p_order_id;
 select coalesce(sum(amount_iqd),0)::bigint,count(*)::bigint
  into v_cash,v_receipts from public.gs_cash_payments where order_id=p_order_id;
 if v_total<=0 or v_cash<>v_total or v_receipts=0 then
  raise exception 'Cash receipts do not exactly match the order total'; end if;
 -- Deliberately reject mixed-method and corrected orders rather than infer
 -- settlement from provisional ledger or unverifiable physical refunds.
 if exists(select 1 from public.gs_cash_correction_postings where order_id=p_order_id)
  or exists(select 1 from public.gs_unified_payment_ledger where order_id=p_order_id)
  or exists(select 1 from public.gs_external_payment_evidence where order_id=p_order_id)
  or exists(select 1 from public.gs_owner_guest_offers where order_id=p_order_id)
  or exists(select 1 from public.gs_table_bill_transfer_request_items i
    join public.gs_order_items oi on oi.id=i.order_item_id
    where oi.order_id=p_order_id)
  or exists(select 1 from public.gs_cash_payments c
    where c.order_id=p_order_id and c.collected_by=auth.uid()) then
  raise exception 'Mixed, corrected, transferred or self-collected order cannot be attested';
 end if;
 insert into public.gs_cash_only_settlement_attestations
  (order_id,table_visit_id,order_total_iqd,collected_cash_iqd,receipt_count,attested_by)
 values(p_order_id,v_order.table_visit_id,v_total,v_cash,v_receipts,auth.uid())
 returning id into v_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','cash_only_settlement_attested',
  p_order_id::text,jsonb_build_object('attestation_id',v_id,
  'cash_iqd',v_cash,'checkout_allowed',false));
 return v_id;
end; $$;
revoke all on function public.gs_attest_cash_only_order_settlement(bigint) from public,anon;
grant execute on function public.gs_attest_cash_only_order_settlement(bigint) to authenticated;
