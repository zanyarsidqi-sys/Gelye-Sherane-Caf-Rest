-- Upgrade 100: MFA finance review of cash correction requests (DRAFT).
-- Review decisions are NOT financial postings and never alter a receipt.
create table if not exists public.gs_cash_correction_finance_reviewers (
 user_id uuid primary key references auth.users(id) on delete restrict,
 enabled boolean not null default true,
 provisioned_at timestamptz not null default now()
);
alter table public.gs_cash_correction_finance_reviewers enable row level security;
revoke all on public.gs_cash_correction_finance_reviewers from public,anon,authenticated;
-- Provision reviewer identities only using trusted database administration.

create table if not exists public.gs_cash_correction_finance_reviews (
 id bigint generated always as identity primary key,
 correction_request_id bigint not null unique
  references public.gs_cash_receipt_correction_requests(id) on delete restrict,
 reviewer_id uuid not null references auth.users(id) on delete restrict,
 decision text not null check (decision in ('rejected','approved_for_posting')),
 adjustment_snapshot_iqd bigint not null check (adjustment_snapshot_iqd<>0),
 reason text not null check (char_length(btrim(reason)) between 10 and 500),
 reviewed_at timestamptz not null default now()
);
alter table public.gs_cash_correction_finance_reviews enable row level security;
revoke all on public.gs_cash_correction_finance_reviews from public,anon,authenticated;

create or replace function public.gs_review_cash_receipt_correction(
 p_request_id bigint,p_decision text,p_reason text)
returns bigint language plpgsql security definer set search_path='' as $$
declare
 v_request public.gs_cash_receipt_correction_requests%rowtype;
 v_receipt public.gs_cash_payments%rowtype;
 v_review_id bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2' then
  raise exception 'Authenticated MFA session required for finance review';
 end if;
 if not exists (select 1 from public.gs_cash_correction_finance_reviewers
                where user_id=auth.uid() and enabled) then
  raise exception 'Finance reviewer not provisioned';
 end if;
 if p_request_id is null or p_decision not in ('rejected','approved_for_posting')
    or char_length(btrim(coalesce(p_reason,''))) not between 10 and 500 then
  raise exception 'Invalid review request';
 end if;
 select * into v_request from public.gs_cash_receipt_correction_requests
  where id=p_request_id for update;
 if not found or v_request.status<>'pending' then
  raise exception 'Pending correction request not found';
 end if;
 if v_request.requested_by=auth.uid() then
  raise exception 'Requester cannot review their own correction';
 end if;
 select * into v_receipt from public.gs_cash_payments
  where id=v_request.cash_receipt_id for share;
 if not found or v_receipt.order_id is distinct from v_request.order_id then
  raise exception 'Cash receipt/order mismatch';
 end if;
 if v_request.requested_adjustment_iqd<0
    and -v_request.requested_adjustment_iqd>v_receipt.amount_iqd then
  raise exception 'Correction exceeds original receipt';
 end if;
 insert into public.gs_cash_correction_finance_reviews(
  correction_request_id,reviewer_id,decision,adjustment_snapshot_iqd,reason)
 values(p_request_id,auth.uid(),p_decision,
        v_request.requested_adjustment_iqd,btrim(p_reason))
 returning id into v_review_id;
 if p_decision='rejected' then
  update public.gs_cash_receipt_correction_requests
  set status='rejected',resolved_by=auth.uid(),resolved_at=now(),
      resolution_note=btrim(p_reason)
  where id=p_request_id;
 end if;
 -- 'approved_for_posting' deliberately leaves the correction pending:
 -- no receipt mutation, ledger adjustment, refund, or settlement occurs.
 insert into public.gs_system_audit_events(
  actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','cash_correction_finance_review',
  p_request_id::text,
  jsonb_build_object('review_id',v_review_id,'decision',p_decision,
   'adjustment_iqd',v_request.requested_adjustment_iqd,
   'reviewer_aal','aal2'));
 return v_review_id;
end; $$;
revoke all on function public.gs_review_cash_receipt_correction(bigint,text,text)
 from public,anon;
grant execute on function public.gs_review_cash_receipt_correction(bigint,text,text)
 to authenticated;
-- Important: AAL2 does not guarantee recent MFA. Verify freshness and
-- build a separate authoritative correction-posting workflow before launch.
