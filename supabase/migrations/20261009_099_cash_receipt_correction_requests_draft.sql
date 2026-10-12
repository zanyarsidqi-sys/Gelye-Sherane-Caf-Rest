-- Upgrade 99: immutable cash receipt correction requests (DRAFT).
-- Requests NEVER modify receipts, balances, ledger, or checkout status.
create table if not exists public.gs_cash_receipt_correction_requests (
 id bigint generated always as identity primary key,
 request_key uuid not null unique,
 cash_receipt_id bigint not null references public.gs_cash_payments(id) on delete restrict,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 requested_adjustment_iqd bigint not null check (requested_adjustment_iqd <> 0),
 reason text not null check (char_length(btrim(reason)) between 10 and 500),
 status text not null default 'pending' check (status in ('pending','rejected','cancelled','resolved_externally')),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 resolved_by uuid references auth.users(id),
 resolved_at timestamptz,
 resolution_note text,
 constraint gs_cash_correction_resolution_consistency check (
  (status='pending' and resolved_by is null and resolved_at is null)
  or (status<>'pending' and resolved_by is not null and resolved_at is not null))
);
create index if not exists gs_cash_correction_receipt_idx
 on public.gs_cash_receipt_correction_requests(cash_receipt_id,requested_at desc);
create unique index if not exists gs_cash_correction_one_pending_per_receipt
 on public.gs_cash_receipt_correction_requests(cash_receipt_id)
 where status='pending';
alter table public.gs_cash_receipt_correction_requests enable row level security;
revoke all on public.gs_cash_receipt_correction_requests from public,anon,authenticated;

create or replace function public.gs_request_cash_receipt_correction(
 p_cash_receipt_id bigint,p_adjustment_iqd bigint,p_reason text,p_request_key uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_receipt public.gs_cash_payments%rowtype;
 v_existing public.gs_cash_receipt_correction_requests%rowtype;
 v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_edit') then
  raise exception 'Not authorized to request cash receipt corrections';
 end if;
 if p_request_key is null or p_cash_receipt_id is null or
  p_adjustment_iqd is null or p_adjustment_iqd=0 or
  char_length(btrim(coalesce(p_reason,''))) not between 10 and 500 then
  raise exception 'Invalid correction request';
 end if;
 select * into v_receipt from public.gs_cash_payments
  where id=p_cash_receipt_id for share;
 if not found then raise exception 'Cash receipt not found'; end if;
 -- Never allow a proposed downward adjustment greater than the receipt.
 if p_adjustment_iqd<0 and -p_adjustment_iqd>v_receipt.amount_iqd then
  raise exception 'Proposed correction exceeds original cash receipt';
 end if;
 select * into v_existing from public.gs_cash_receipt_correction_requests
  where request_key=p_request_key;
 if found then
  if v_existing.cash_receipt_id=p_cash_receipt_id
   and v_existing.requested_adjustment_iqd=p_adjustment_iqd
   and v_existing.reason=btrim(p_reason)
   and v_existing.requested_by=auth.uid() then return v_existing.id; end if;
  raise exception 'Correction request key already used';
 end if;
 insert into public.gs_cash_receipt_correction_requests(
  request_key,cash_receipt_id,order_id,requested_adjustment_iqd,reason,requested_by)
 values(p_request_key,p_cash_receipt_id,v_receipt.order_id,
  p_adjustment_iqd,btrim(p_reason),auth.uid()) returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_request_cash_receipt_correction(bigint,bigint,text,uuid)
 from public,anon;
grant execute on function public.gs_request_cash_receipt_correction(bigint,bigint,text,uuid)
 to authenticated;
-- Pending requests are review-only. No approval/posting endpoint is granted.
