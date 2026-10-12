-- Upgrade 102: idempotent cash correction posting-intent preparation.
-- This is NOT a posting RPC. No balances, cash receipts or ledgers change.
create table if not exists public.gs_cash_correction_posting_intents (
 id bigint generated always as identity primary key,
 request_id bigint not null unique references public.gs_cash_receipt_correction_requests(id) on delete restrict,
 review_id bigint not null unique references public.gs_cash_correction_finance_reviews(id) on delete restrict,
 intent_key uuid not null unique,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 cash_receipt_id bigint not null references public.gs_cash_payments(id) on delete restrict,
 adjustment_snapshot_iqd bigint not null check(adjustment_snapshot_iqd <> 0),
 prepared_by uuid not null references auth.users(id) on delete restrict,
 prepared_at timestamptz not null default now(),
 status text not null default 'awaiting_trusted_posting'
  check(status='awaiting_trusted_posting')
);
alter table public.gs_cash_correction_posting_intents enable row level security;
revoke all on public.gs_cash_correction_posting_intents from public,anon,authenticated;

create or replace function public.gs_prepare_cash_correction_posting_intent(
 p_request_id bigint,p_intent_key uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_request public.gs_cash_receipt_correction_requests%rowtype;
 v_review public.gs_cash_correction_finance_reviews%rowtype;
 v_receipt public.gs_cash_payments%rowtype;
 v_existing public.gs_cash_correction_posting_intents%rowtype;
 v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_edit') then
  raise exception 'Financial correction permission denied'; end if;
 if p_request_id is null or p_intent_key is null then
  raise exception 'Request and idempotency key required'; end if;
 -- Serialize retries for a given request, including competing intent keys.
 select * into v_request from public.gs_cash_receipt_correction_requests
  where id=p_request_id for update;
 if not found or v_request.status<>'pending' then
  raise exception 'Pending correction request not found'; end if;
 select * into v_existing from public.gs_cash_correction_posting_intents
  where request_id=p_request_id;
 if found then
  if v_existing.intent_key=p_intent_key then return v_existing.id; end if;
  raise exception 'A posting intent already exists for this correction';
 end if;
 if exists(select 1 from public.gs_cash_correction_posting_intents
  where intent_key=p_intent_key) then
  raise exception 'Posting intent key belongs to a different correction'; end if;
 select * into v_review from public.gs_cash_correction_finance_reviews
  where correction_request_id=p_request_id;
 if not found or v_review.decision<>'approved_for_posting' or
  v_review.adjustment_snapshot_iqd is distinct from v_request.requested_adjustment_iqd or
  v_review.reviewer_id=v_request.requested_by then
  raise exception 'Independent finance approval required'; end if;
 select * into v_receipt from public.gs_cash_payments
  where id=v_request.cash_receipt_id for share;
 if not found or v_receipt.order_id is distinct from v_request.order_id then
  raise exception 'Original receipt/order mismatch'; end if;
 if v_request.requested_adjustment_iqd<0 and
  -v_request.requested_adjustment_iqd>v_receipt.amount_iqd then
  raise exception 'Adjustment exceeds original receipt'; end if;
 -- Do not create an intent while any conflicting correction remains pending.
 if exists(select 1 from public.gs_cash_receipt_correction_requests c
  where c.cash_receipt_id=v_request.cash_receipt_id
   and c.id<>p_request_id and c.status='pending') then
  raise exception 'Conflicting correction request'; end if;
 insert into public.gs_cash_correction_posting_intents(
  request_id,review_id,intent_key,order_id,cash_receipt_id,
  adjustment_snapshot_iqd,prepared_by)
 values(v_request.id,v_review.id,p_intent_key,v_request.order_id,
  v_request.cash_receipt_id,v_request.requested_adjustment_iqd,auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_prepare_cash_correction_posting_intent(bigint,uuid)
 from public,anon;
grant execute on function public.gs_prepare_cash_correction_posting_intent(bigint,uuid)
 to authenticated;
-- No INSERT grants on the intent table. No posting function or financial mutation.
