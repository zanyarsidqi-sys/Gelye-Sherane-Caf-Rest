-- Upgrade 61: payment-method reconciliation foundation (DRAFT).
-- The current project only has a verifiable gs_cash_payments ledger.
-- Never assume that missing card/online/credit records means no payment.
create table if not exists public.gs_external_payment_evidence (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 method text not null check (method in ('card','online','credit','other')),
 external_reference text not null,
 amount_iqd bigint not null check (amount_iqd>0),
 verification_status text not null default 'unverified'
   check (verification_status in ('unverified','pending','verified','rejected')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id),
 verified_at timestamptz,
 verified_by uuid references auth.users(id),
 unique(method,external_reference),
 check ((verification_status='verified') =
        (verified_at is not null and verified_by is not null))
);
create index if not exists gs_external_payment_evidence_order_idx
 on public.gs_external_payment_evidence(order_id);
alter table public.gs_external_payment_evidence enable row level security;
revoke all on public.gs_external_payment_evidence from public,anon,authenticated;
-- No write/read grants or approval RPC. Evidence must originate from
-- trusted provider/credit-account verification, never a staff assertion.

create or replace function public.gs_dashboard_order_settlement_safety(p_order_id bigint)
returns table(
 order_id bigint, order_total_iqd bigint, cash_recorded_iqd bigint,
 external_verified_iqd bigint, external_unverified_count bigint,
 cash_remaining_iqd bigint, settlement_status text,
 transfer_safe boolean
)
language plpgsql stable security definer set search_path='' as $$
declare
 v_order public.gs_orders%rowtype;
 v_total bigint;
 v_cash bigint;
 v_verified bigint;
 v_unverified bigint;
begin
 if auth.uid() is null or not (
    public.gs_can_access('invoices_payments','can_view')
    or public.gs_can_access('payments_management','can_view')
 ) then raise exception 'Financial reconciliation permission denied'; end if;
 select * into v_order from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Order not found'; end if;
 select coalesce(sum(i.line_total_iqd),0)::bigint into v_total
  from public.gs_order_items i where i.order_id=p_order_id;
 select coalesce(sum(p.amount_iqd),0)::bigint into v_cash
  from public.gs_cash_payments p where p.order_id=p_order_id;
 select coalesce(sum(e.amount_iqd) filter
      (where e.verification_status='verified'),0)::bigint,
   count(*) filter(where e.verification_status<>'verified')::bigint
 into v_verified,v_unverified
 from public.gs_external_payment_evidence e where e.order_id=p_order_id;
 return query select v_order.id,v_total,v_cash,v_verified,v_unverified,
  greatest(v_total-v_cash-v_verified,0)::bigint,
  case
   when v_order.status='cancelled' then 'cancelled_review'
   when v_total<=0 then 'no_charge_review'
   when v_cash+v_verified>v_total then 'overpayment_investigate'
   when v_unverified>0 then 'unverified_external_evidence'
   when v_cash+v_verified=v_total then 'recorded_ledger_covers_total_not_final'
   else 'outstanding_or_unrecorded_payment'
  end::text,
  false; -- ALWAYS FALSE: other real-world payment methods may be unrecorded.
end; $$;
revoke all on function public.gs_dashboard_order_settlement_safety(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_order_settlement_safety(bigint)
 to authenticated;
-- Production requires authenticated payment-provider callbacks, credit
-- debit reservations, owner waivers, and locked unified ledger reconciliation
-- before transfer_safe can ever be true.
