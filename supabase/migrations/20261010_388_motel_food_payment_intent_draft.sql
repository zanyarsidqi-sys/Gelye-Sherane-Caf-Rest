-- Upgrade 388: payment preparation only. No settlement, cashier posting or credit debit.
create table if not exists public.gs_motel_food_payment_intent_drafts (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id),
 method text not null check(method in ('cash','credit','electronic')),
 amount_iqd bigint not null check(amount_iqd>0),
 status text not null default 'draft' check(status='draft'),
 idempotency_key uuid not null,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique(finance_invoice_id,idempotency_key)
);
create unique index if not exists gs_motel_food_one_active_payment_draft
 on public.gs_motel_food_payment_intent_drafts(finance_invoice_id);
alter table public.gs_motel_food_payment_intent_drafts enable row level security;
revoke all on public.gs_motel_food_payment_intent_drafts from public,anon,authenticated;

create or replace function public.gs_staff_prepare_motel_food_payment(
 p_finance_invoice_id uuid,p_method text,p_idempotency_key uuid)
returns table(intent_id uuid,already_prepared boolean,amount_iqd bigint,method text)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_finance_invoices%rowtype;
 v_existing public.gs_motel_food_payment_intent_drafts%rowtype;
 v_check record; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and finance editing permissions required';
 end if;
 if p_method not in ('cash','credit','electronic') or p_method is null then
  raise exception 'Unsupported payment method';
 end if;
 if p_idempotency_key is null then raise exception 'Idempotency key required'; end if;
 select * into v from public.gs_motel_food_finance_invoices f
 where f.id=p_finance_invoice_id for update;
 if not found then raise exception 'Finance invoice not found'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(v.id);
 if v_check.check_status is distinct from 'matched' or v.payment_status <> 'unpaid'
 or v.total_iqd<=0 then raise exception 'Invoice not eligible for payment preparation'; end if;
 select * into v_existing from public.gs_motel_food_payment_intent_drafts d
 where d.finance_invoice_id=v.id for update;
 if found then
  if v_existing.idempotency_key is distinct from p_idempotency_key
    or v_existing.method is distinct from p_method
    or v_existing.amount_iqd is distinct from v.total_iqd then
    raise exception 'Payment draft already exists; review it before any further action';
  end if;
  return query select v_existing.id,true,v_existing.amount_iqd,v_existing.method;return;
 end if;
 insert into public.gs_motel_food_payment_intent_drafts
 (finance_invoice_id,method,amount_iqd,idempotency_key,created_by)
 values(v.id,p_method,v.total_iqd,p_idempotency_key,auth.uid()) returning id into v_id;
 return query select v_id,false,v.total_iqd,p_method;
end; $$;
revoke all on function public.gs_staff_prepare_motel_food_payment(uuid,text,uuid) from public,anon;
grant execute on function public.gs_staff_prepare_motel_food_payment(uuid,text,uuid) to authenticated;

create or replace function public.gs_staff_list_motel_food_payment_drafts()
returns table(intent_id uuid,finance_invoice_id uuid,method text,amount_iqd bigint,status text,created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Finance viewing permissions required';
 end if;
 return query select d.id,d.finance_invoice_id,d.method,d.amount_iqd,d.status,d.created_at
 from public.gs_motel_food_payment_intent_drafts d order by d.created_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_food_payment_drafts() from public,anon;
grant execute on function public.gs_staff_list_motel_food_payment_drafts() to authenticated;
