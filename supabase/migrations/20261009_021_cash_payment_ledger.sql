-- Phase 3 step 2: cash collection ledger. Review before deployment.
-- Only authenticated employees with invoices_payments:create can collect cash.
create table if not exists public.gs_cash_payments (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 amount_iqd bigint not null check (amount_iqd > 0),
 reference uuid not null unique,
 collected_by uuid not null references auth.users(id),
 collected_at timestamptz not null default now()
);
create index if not exists gs_cash_payments_order_idx on public.gs_cash_payments(order_id);
alter table public.gs_cash_payments enable row level security;
revoke all on public.gs_cash_payments from anon, authenticated;
grant select on public.gs_cash_payments to authenticated;
drop policy if exists gs_cash_payments_read on public.gs_cash_payments;
create policy gs_cash_payments_read on public.gs_cash_payments for select to authenticated
 using (public.gs_can_access('invoices_payments') or public.gs_can_access('payments_management'));
create or replace function public.gs_record_cash_payment(p_order_id bigint, p_amount_iqd bigint, p_reference uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_order public.gs_orders%rowtype; v_due bigint; v_paid bigint; v_existing public.gs_cash_payments%rowtype; v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_create') then
  raise exception 'Not authorized to collect cash';
 end if;
 if p_order_id is null or p_reference is null or p_amount_iqd is null or p_amount_iqd <= 0 then
  raise exception 'Invalid payment request';
 end if;
 -- Serializes all payment writers for this order, preventing overpayment races.
 select * into v_order from public.gs_orders where id = p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 select * into v_existing from public.gs_cash_payments where reference = p_reference;
 if found then
  if v_existing.order_id = p_order_id and v_existing.amount_iqd = p_amount_iqd then return v_existing.id; end if;
  raise exception 'Payment reference already used';
 end if;
 if v_order.status = 'cancelled' then raise exception 'Cannot pay a cancelled order'; end if;
 select coalesce(sum(line_total_iqd),0) into v_due from public.gs_order_items where order_id = p_order_id;
 select coalesce(sum(amount_iqd),0) into v_paid from public.gs_cash_payments where order_id = p_order_id;
 if v_due <= 0 or p_amount_iqd > v_due - v_paid then raise exception 'Payment exceeds outstanding order amount'; end if;
 insert into public.gs_cash_payments(order_id,amount_iqd,reference,collected_by)
 values(p_order_id,p_amount_iqd,p_reference,auth.uid()) returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.gs_record_cash_payment(bigint,bigint,uuid) from public, anon;
grant execute on function public.gs_record_cash_payment(bigint,bigint,uuid) to authenticated;
-- Random UUID provided by PostgreSQL; authenticated only.
create or replace function public.gs_new_payment_reference() returns uuid
language sql volatile security invoker set search_path = '' as $$ select gen_random_uuid() $$;
revoke all on function public.gs_new_payment_reference() from public, anon;
grant execute on function public.gs_new_payment_reference() to authenticated;
