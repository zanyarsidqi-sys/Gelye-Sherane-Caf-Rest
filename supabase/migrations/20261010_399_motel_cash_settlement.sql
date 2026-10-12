-- Upgrade 399: UUID-native motel food cash settlement ledger.
-- Atomic settlement within the motel-food finance namespace; NOT the legacy numeric-order ledger.
alter table public.gs_motel_food_finance_invoices
 drop constraint if exists gs_motel_food_finance_invoices_payment_status_check;
alter table public.gs_motel_food_finance_invoices
 add constraint gs_motel_food_finance_invoices_payment_status_check
 check(payment_status in ('unpaid','paid_cash'));

create table if not exists public.gs_motel_food_cash_settlements (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id),
 intent_id uuid not null unique references public.gs_motel_food_payment_intent_drafts(id),
 review_id uuid not null unique references public.gs_motel_cash_confirmation_reviews(id),
 amount_iqd bigint not null check(amount_iqd>0),
 receipt_reference text not null unique,
 settled_by uuid not null references auth.users(id),
 settled_at timestamptz not null default now()
);
alter table public.gs_motel_food_cash_settlements enable row level security;
revoke all on public.gs_motel_food_cash_settlements from public,anon,authenticated;

create or replace function public.gs_staff_settle_motel_food_cash(p_intent_id uuid)
returns table(settlement_id uuid, already_settled boolean, receipt_reference text, settled_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
 v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_r public.gs_motel_cash_confirmation_reviews%rowtype;
 v_s public.gs_motel_food_cash_settlements%rowtype;
 v_check record;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Authorized finance editor required';
 end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id for update;
 if not found or v_d.method<>'cash' or v_d.status<>'draft' then
  raise exception 'Active cash payment draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id for update;
 if not found then raise exception 'Finance invoice missing'; end if;
 select * into v_s from public.gs_motel_food_cash_settlements where finance_invoice_id=v_f.id;
 if found then
  if v_s.intent_id<>v_d.id or v_f.payment_status<>'paid_cash' then
   raise exception 'Invoice already settled under a different payment'; end if;
  return query select v_s.id,true,v_s.receipt_reference,v_s.settled_at; return;
 end if;
 if v_f.payment_status<>'unpaid' or v_f.total_iqd<=0 or v_f.total_iqd<>v_d.amount_iqd then
  raise exception 'Invoice is not eligible for cash settlement'; end if;
 select * into v_r from public.gs_motel_cash_confirmation_reviews where intent_id=v_d.id for update;
 if not found or v_r.finance_invoice_id<>v_f.id or v_r.amount_iqd<>v_f.total_iqd
 or v_r.review_status<>'cash_received_pending_settlement'
 or v_r.cash_received_by is null or v_r.cash_received_at is null
 or nullif(btrim(v_r.cash_receipt_reference),'') is null then
  raise exception 'Verified physical cash receipt acknowledgement required'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(v_f.id);
 if v_check.check_status is distinct from 'matched' then
  raise exception 'Invoice source reconciliation failed'; end if;
 insert into public.gs_motel_food_cash_settlements
 (finance_invoice_id,intent_id,review_id,amount_iqd,receipt_reference,settled_by)
 values(v_f.id,v_d.id,v_r.id,v_f.total_iqd,v_r.cash_receipt_reference,auth.uid())
 returning * into v_s;
 update public.gs_motel_food_finance_invoices set payment_status='paid_cash' where id=v_f.id;
 return query select v_s.id,false,v_s.receipt_reference,v_s.settled_at;
end; $$;
revoke all on function public.gs_staff_settle_motel_food_cash(uuid) from public,anon;
grant execute on function public.gs_staff_settle_motel_food_cash(uuid) to authenticated;
