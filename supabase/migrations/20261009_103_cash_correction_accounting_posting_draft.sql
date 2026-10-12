-- Upgrade 103: actual, append-only negative cash correction posting.
-- Accounting adjustment ONLY; does not refund physical cash or certify settlement.
create table if not exists public.gs_cash_correction_postings (
 id bigint generated always as identity primary key,
 intent_id bigint not null unique references public.gs_cash_correction_posting_intents(id),
 request_id bigint not null unique references public.gs_cash_receipt_correction_requests(id),
 cash_receipt_id bigint not null references public.gs_cash_payments(id),
 order_id bigint not null references public.gs_orders(id),
 adjustment_iqd bigint not null check (adjustment_iqd < 0),
 posted_by uuid not null references auth.users(id),
 posted_at timestamptz not null default now()
);
alter table public.gs_cash_correction_postings enable row level security;
revoke all on public.gs_cash_correction_postings from public,anon,authenticated;
create or replace function public.gs_reject_cash_correction_posting_changes()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Posted corrections are immutable'; end; $$;
drop trigger if exists gs_cash_correction_postings_immutable on public.gs_cash_correction_postings;
create trigger gs_cash_correction_postings_immutable before update or delete
 on public.gs_cash_correction_postings for each row
 execute function public.gs_reject_cash_correction_posting_changes();

create or replace function public.gs_post_approved_cash_correction(p_intent_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_intent public.gs_cash_correction_posting_intents%rowtype;
 v_request public.gs_cash_receipt_correction_requests%rowtype;
 v_review public.gs_cash_correction_finance_reviews%rowtype;
 v_receipt public.gs_cash_payments%rowtype;
 v_post public.gs_cash_correction_postings%rowtype;
 v_post_id bigint; v_existing bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
  or not public.gs_can_access('invoices_payments','can_edit')
  or not exists(select 1 from public.gs_cash_correction_finance_reviewers
    where user_id=auth.uid() and enabled) then
  raise exception 'Provisioned finance reviewer with MFA and edit permission required';
 end if;
 if p_intent_id is null then raise exception 'Intent required'; end if;
 select * into v_intent from public.gs_cash_correction_posting_intents
  where id=p_intent_id for update;
 if not found then raise exception 'Intent not found'; end if;
 select * into v_post from public.gs_cash_correction_postings where intent_id=p_intent_id;
 if found then return v_post.id; end if;
 select * into v_request from public.gs_cash_receipt_correction_requests
  where id=v_intent.request_id for update;
 select * into v_review from public.gs_cash_correction_finance_reviews
  where id=v_intent.review_id;
 select * into v_receipt from public.gs_cash_payments
  where id=v_intent.cash_receipt_id for update;
 if v_request.id is null or v_review.id is null or v_receipt.id is null
  or v_request.status <> 'pending'
  or v_review.decision <> 'approved_for_posting'
  or v_review.correction_request_id <> v_request.id
  or v_review.reviewer_id = v_request.requested_by
  or v_intent.prepared_by = auth.uid()
  or v_review.reviewer_id = auth.uid()
  or v_request.cash_receipt_id <> v_receipt.id
  or v_request.order_id <> v_receipt.order_id
  or v_intent.order_id <> v_receipt.order_id
  or v_intent.adjustment_snapshot_iqd <> v_request.requested_adjustment_iqd
  or v_review.adjustment_snapshot_iqd <> v_request.requested_adjustment_iqd then
  raise exception 'Correction review, intent or receipt mismatch';
 end if;
 -- Positive corrections need a separate cash collection, not an accounting-only credit.
 if v_intent.adjustment_snapshot_iqd >= 0 or
  -v_intent.adjustment_snapshot_iqd > v_receipt.amount_iqd then
  raise exception 'Only bounded negative cash accounting corrections are supported';
 end if;
 if exists(select 1 from public.gs_cash_correction_postings
  where cash_receipt_id=v_receipt.id) then
  raise exception 'Receipt already has a posted correction';
 end if;
 insert into public.gs_cash_correction_postings(
  intent_id,request_id,cash_receipt_id,order_id,adjustment_iqd,posted_by)
 values(v_intent.id,v_request.id,v_receipt.id,v_receipt.order_id,
  v_intent.adjustment_snapshot_iqd,auth.uid()) returning id into v_post_id;
 -- Do not claim physical cash was refunded or mutate the original receipt.
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','cash_correction_accounting_posted',
  v_request.id::text,jsonb_build_object('posting_id',v_post_id,
  'adjustment_iqd',v_intent.adjustment_snapshot_iqd,
  'physical_refund_confirmed',false));
 return v_post_id;
end; $$;
revoke all on function public.gs_post_approved_cash_correction(bigint) from public,anon;
grant execute on function public.gs_post_approved_cash_correction(bigint) to authenticated;

create or replace function public.gs_cash_receipt_net_after_posted_correction(p_receipt_id bigint)
returns table(receipt_id bigint,original_iqd bigint,posted_adjustment_iqd bigint,
 accounting_net_iqd bigint,physical_refund_confirmed boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_view') then
  raise exception 'Finance view permission required'; end if;
 return query select c.id,c.amount_iqd,
  coalesce(sum(p.adjustment_iqd),0)::bigint,
  (c.amount_iqd+coalesce(sum(p.adjustment_iqd),0))::bigint,false
 from public.gs_cash_payments c
 left join public.gs_cash_correction_postings p on p.cash_receipt_id=c.id
 where c.id=p_receipt_id group by c.id,c.amount_iqd;
end; $$;
revoke all on function public.gs_cash_receipt_net_after_posted_correction(bigint) from public,anon;
grant execute on function public.gs_cash_receipt_net_after_posted_correction(bigint) to authenticated;
