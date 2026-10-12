-- Upgrade 398: explicit cashier acknowledgement of cash physically received.
-- This is a receipt attestation ONLY. It does not post the unified ledger or mark an invoice paid.
-- A separate, audited settlement integration is required before closing the invoice.
alter table public.gs_motel_cash_confirmation_reviews
 add column if not exists cash_received_by uuid references auth.users(id),
 add column if not exists cash_received_at timestamptz,
 add column if not exists cash_receipt_reference text,
 add column if not exists cash_received_note text;
alter table public.gs_motel_cash_confirmation_reviews drop constraint if exists gs_motel_cash_confirmation_reviews_review_status_check;
alter table public.gs_motel_cash_confirmation_reviews add constraint gs_motel_cash_confirmation_reviews_review_status_check
 check(review_status in ('pending_cashier_confirmation','cash_received_pending_settlement'));
create unique index if not exists gs_motel_cash_receipt_reference_unique
 on public.gs_motel_cash_confirmation_reviews(cash_receipt_reference)
 where cash_receipt_reference is not null;

create or replace function public.gs_staff_acknowledge_motel_cash_received(p_intent_id uuid,p_receipt_reference text,p_note text default null)
returns table(review_id uuid,review_status text,received_at timestamptz,already_acknowledged boolean)
language plpgsql security definer set search_path = '' as $$
declare v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_r public.gs_motel_cash_confirmation_reviews%rowtype;
 v_check record;
 v_ref text := nullif(btrim(p_receipt_reference),'');
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Finance editing permission required'; end if;
 if v_ref is null or length(v_ref)>100 then raise exception 'Receipt reference required (maximum 100 characters)'; end if;
 if length(coalesce(p_note,''))>1000 then raise exception 'Note too long'; end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id for update;
 if not found or v_d.status<>'draft' or v_d.method<>'cash' then raise exception 'Active cash draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id for update;
 if not found or v_f.payment_status<>'unpaid' or v_f.total_iqd<>v_d.amount_iqd then
  raise exception 'Invoice is not eligible for cash acknowledgement'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(v_f.id);
 if v_check.check_status is distinct from 'matched' then raise exception 'Invoice reconciliation failed'; end if;
 select * into v_r from public.gs_motel_cash_confirmation_reviews where intent_id=v_d.id for update;
 if not found or v_r.finance_invoice_id<>v_f.id or v_r.amount_iqd<>v_f.total_iqd then
  raise exception 'Matching cashier review required'; end if;
 if v_r.review_status='cash_received_pending_settlement' then
  if v_r.cash_receipt_reference is distinct from v_ref then raise exception 'Cash already acknowledged under a different receipt'; end if;
  return query select v_r.id,v_r.review_status,v_r.cash_received_at,true; return;
 end if;
 update public.gs_motel_cash_confirmation_reviews
 set review_status='cash_received_pending_settlement',cash_received_by=auth.uid(),
 cash_received_at=now(),cash_receipt_reference=v_ref,cash_received_note=nullif(btrim(p_note),'')
 where id=v_r.id returning * into v_r;
 return query select v_r.id,v_r.review_status,v_r.cash_received_at,false;
end; $$;
revoke all on function public.gs_staff_acknowledge_motel_cash_received(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_acknowledge_motel_cash_received(uuid,text,text) to authenticated;

-- A cash receipt cannot be silently cancelled by cancelling its draft.
-- Earlier cancellation RPC remains in place, but its update is blocked for acknowledged receipts.
create or replace function public.gs_guard_acknowledged_motel_cash_draft()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.status='draft' and new.status='cancelled' and exists (
  select 1 from public.gs_motel_cash_confirmation_reviews r
  where r.intent_id=old.id and r.review_status='cash_received_pending_settlement'
 ) then raise exception 'Cash received: cannot cancel draft; finance reversal workflow required'; end if;
 return new;
end; $$;
drop trigger if exists gs_guard_acknowledged_motel_cash_draft on public.gs_motel_food_payment_intent_drafts;
create trigger gs_guard_acknowledged_motel_cash_draft before update of status
on public.gs_motel_food_payment_intent_drafts for each row
execute function public.gs_guard_acknowledged_motel_cash_draft();
