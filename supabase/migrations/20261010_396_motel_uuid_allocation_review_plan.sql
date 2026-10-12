-- Upgrade 396: UUID-native, non-posting allocation plan for motel food invoices.
-- This is a durable review artifact, NOT a ledger entry, receipt, or credit debit.
create table if not exists public.gs_motel_food_payment_allocation_plans (
 id uuid primary key default extensions.gen_random_uuid(),
 intent_id uuid not null unique references public.gs_motel_food_payment_intent_drafts(id) on delete restrict,
 finance_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id) on delete restrict,
 source_bridge_id uuid not null references public.gs_motel_finance_source_bridge(id) on delete restrict,
 amount_iqd bigint not null check(amount_iqd>0),
 method text not null check(method in ('cash','credit','electronic')),
 plan_status text not null default 'review_only' check(plan_status='review_only'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 constraint gs_motel_allocation_plan_no_legacy_posting check(plan_status='review_only')
);
alter table public.gs_motel_food_payment_allocation_plans enable row level security;
revoke all on public.gs_motel_food_payment_allocation_plans from public,anon,authenticated;

create or replace function public.gs_staff_prepare_motel_allocation_plan(p_intent_id uuid)
returns table(plan_id uuid, already_prepared boolean, plan_status text, amount_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_b public.gs_motel_finance_source_bridge%rowtype;
 v_p public.gs_motel_food_payment_allocation_plans%rowtype;
 v_check record; v_invoice_check record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and finance editing permissions required';
 end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id for update;
 if not found or v_d.status<>'draft' then raise exception 'Active payment draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices where id=v_d.finance_invoice_id for update;
 if not found or v_f.payment_status<>'unpaid' or v_d.amount_iqd<>v_f.total_iqd then
  raise exception 'Invoice must be unpaid and match draft amount';
 end if;
 select * into v_check from public.gs_staff_check_motel_food_payment_draft(v_d.id);
 if v_check.check_status is distinct from 'ready_for_future_integration' then
  raise exception 'Payment draft integrity verification failed'; end if;
 select * into v_invoice_check from public.gs_staff_check_motel_food_finance_invoice(v_f.id);
 if v_invoice_check.check_status is distinct from 'matched' then
  raise exception 'Invoice source reconciliation failed'; end if;
 select * into v_b from public.gs_motel_finance_source_bridge where finance_invoice_id=v_f.id for update;
 if not found or v_b.amount_iqd<>v_f.total_iqd or v_b.guest_session_id<>v_f.guest_session_id
 or v_b.room_id<>v_f.room_id or v_b.source_fingerprint<>v_f.source_fingerprint
 or v_b.legacy_order_id is not null or v_b.mapping_status<>'unmapped' then
  raise exception 'Verified UUID finance source required; legacy link prohibited'; end if;
 select * into v_p from public.gs_motel_food_payment_allocation_plans where intent_id=v_d.id;
 if found then
  if v_p.finance_invoice_id<>v_f.id or v_p.source_bridge_id<>v_b.id
    or v_p.amount_iqd<>v_d.amount_iqd or v_p.method<>v_d.method then
    raise exception 'Existing allocation plan differs from current draft'; end if;
  return query select v_p.id,true,v_p.plan_status,v_p.amount_iqd; return;
 end if;
 insert into public.gs_motel_food_payment_allocation_plans
 (intent_id,finance_invoice_id,source_bridge_id,amount_iqd,method,created_by)
 values(v_d.id,v_f.id,v_b.id,v_d.amount_iqd,v_d.method,auth.uid()) returning * into v_p;
 return query select v_p.id,false,v_p.plan_status,v_p.amount_iqd;
end; $$;
revoke all on function public.gs_staff_prepare_motel_allocation_plan(uuid) from public,anon;
grant execute on function public.gs_staff_prepare_motel_allocation_plan(uuid) to authenticated;
