-- Upgrade 66 DRAFT: provider verification intake and read-only exception queue.
-- No staff or client can self-verify a card, online or credit transaction.
-- Provider callback signature verification must be implemented server-side.
create table if not exists public.gs_payment_verification_inbox (
 id bigint generated always as identity primary key,
 evidence_id bigint not null references public.gs_external_payment_evidence(id),
 provider text not null,
 provider_event_id text not null,
 provider_reference text not null,
 reported_amount_iqd bigint not null check(reported_amount_iqd > 0),
 reported_currency text not null default 'IQD',
 intake_status text not null default 'awaiting_server_verification'
   check(intake_status in ('awaiting_server_verification','rejected','verified_by_server')),
 rejection_reason text,
 received_at timestamptz not null default now(),
 verified_at timestamptz,
 unique(provider,provider_event_id),
 check ((intake_status='verified_by_server')=(verified_at is not null))
);
create index if not exists gs_payment_verification_inbox_evidence_idx
 on public.gs_payment_verification_inbox(evidence_id);
alter table public.gs_payment_verification_inbox enable row level security;
revoke all on public.gs_payment_verification_inbox from public,anon,authenticated;
-- No client-side insert, approve, or update endpoint is exposed.

create or replace function public.gs_dashboard_payment_verification_queue(p_limit integer default 100)
returns table (
 inbox_id bigint, evidence_id bigint, order_id bigint, method text,
 provider text, reported_amount_iqd bigint, expected_amount_iqd bigint,
 reported_currency text, intake_status text, amount_matches boolean,
 received_at timestamptz
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('invoices_payments','can_view')
   or public.gs_can_access('payments_management','can_view')
 ) then raise exception 'Payment verification queue access denied'; end if;
 return query
 select i.id,i.evidence_id,e.order_id,e.method,i.provider,
  i.reported_amount_iqd,e.amount_iqd,i.reported_currency,i.intake_status,
  (i.reported_amount_iqd=e.amount_iqd and i.reported_currency='IQD'),
  i.received_at
 from public.gs_payment_verification_inbox i
 join public.gs_external_payment_evidence e on e.id=i.evidence_id
 where i.intake_status<>'verified_by_server'
 order by i.received_at desc,i.id desc
 limit least(greatest(coalesce(p_limit,100),1),200);
end; $$;
revoke all on function public.gs_dashboard_payment_verification_queue(integer)
 from public,anon;
grant execute on function public.gs_dashboard_payment_verification_queue(integer)
 to authenticated;
-- Provider-specific webhook, signed-event validation, external transaction
-- lookup, verified credit debit, and ledger posting remain unimplemented.
-- Amount matching alone NEVER constitutes verification.
