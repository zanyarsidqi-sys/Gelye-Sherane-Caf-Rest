-- Upgrade 397: cashier confirmation gate; does not represent collection or ledger posting.
-- Invoice schema currently enforces payment_status='unpaid'; do not bypass it.
create table if not exists public.gs_motel_cash_confirmation_reviews (
 id uuid primary key default extensions.gen_random_uuid(),
 allocation_plan_id uuid not null unique references public.gs_motel_food_payment_allocation_plans(id) on delete restrict,
 intent_id uuid not null unique references public.gs_motel_food_payment_intent_drafts(id) on delete restrict,
 finance_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id) on delete restrict,
 amount_iqd bigint not null check(amount_iqd>0),
 review_status text not null default 'pending_cashier_confirmation' check(review_status='pending_cashier_confirmation'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_motel_cash_confirmation_reviews enable row level security;
revoke all on public.gs_motel_cash_confirmation_reviews from public,anon,authenticated;

create or replace function public.gs_staff_prepare_motel_cash_confirmation(p_intent_id uuid)
returns table(review_id uuid,already_prepared boolean,review_status text,amount_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_p public.gs_motel_food_payment_allocation_plans%rowtype;
 v_r public.gs_motel_cash_confirmation_reviews%rowtype;
 v_check record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Finance editing permission required'; end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id for update;
 if not found or v_d.status<>'draft' or v_d.method<>'cash' then
  raise exception 'Active cash draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id for update;
 if not found or v_f.payment_status<>'unpaid' or v_f.total_iqd<>v_d.amount_iqd then
  raise exception 'Unpaid invoice with matching amount required'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(v_f.id);
 if v_check.check_status is distinct from 'matched' then raise exception 'Invoice reconciliation failed'; end if;
 select * into v_p from public.gs_motel_food_payment_allocation_plans where intent_id=v_d.id;
 if not found or v_p.plan_status<>'review_only' or v_p.method<>'cash'
 or v_p.finance_invoice_id<>v_f.id or v_p.amount_iqd<>v_f.total_iqd then
  raise exception 'Valid cash allocation review plan required'; end if;
 select * into v_r from public.gs_motel_cash_confirmation_reviews where intent_id=v_d.id;
 if found then
  if v_r.allocation_plan_id<>v_p.id or v_r.finance_invoice_id<>v_f.id or v_r.amount_iqd<>v_f.total_iqd then
   raise exception 'Existing cashier review mismatch'; end if;
  return query select v_r.id,true,v_r.review_status,v_r.amount_iqd; return;
 end if;
 insert into public.gs_motel_cash_confirmation_reviews
 (allocation_plan_id,intent_id,finance_invoice_id,amount_iqd,created_by)
 values(v_p.id,v_d.id,v_f.id,v_f.total_iqd,auth.uid()) returning * into v_r;
 return query select v_r.id,false,v_r.review_status,v_r.amount_iqd;
end; $$;
revoke all on function public.gs_staff_prepare_motel_cash_confirmation(uuid) from public,anon;
grant execute on function public.gs_staff_prepare_motel_cash_confirmation(uuid) to authenticated;
