-- Upgrade 246: transactionally prepare a locked discounted invoice for a future payment integration.
-- This migration intentionally NEVER posts cash, debits credit, or marks invoices paid.
-- Reconcile all legacy payment writers before implementing capture.
create table if not exists public.gs_locked_discount_payment_intents (
 id bigint generated always as identity primary key,
 snapshot_id bigint not null unique references public.gs_admin_discount_invoice_snapshots(id) on delete restrict,
 order_id bigint not null unique references public.gs_orders(id) on delete restrict,
 amount_due_iqd bigint not null check(amount_due_iqd >= 0),
 status text not null default 'awaiting_integration' check(status='awaiting_integration'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_locked_discount_payment_intents enable row level security;
revoke all on public.gs_locked_discount_payment_intents from public,anon,authenticated;

create or replace function public.gs_prepare_locked_discount_payment(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_snapshot public.gs_admin_discount_invoice_snapshots%rowtype;
 v_intent public.gs_locked_discount_payment_intents%rowtype;
 v_recon jsonb;
begin
 if auth.uid() is null or not exists
   (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id<=0 then raise exception 'Invalid order'; end if;
 -- Serialize all requests per order; order guards already require this lock.
 perform 1 from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 select * into v_snapshot from public.gs_admin_discount_invoice_snapshots
 where order_id=p_order_id;
 if not found then raise exception 'Lock an approved discounted invoice first'; end if;
 -- Existing intent is idempotent; no external payment action is performed.
 select * into v_intent from public.gs_locked_discount_payment_intents
 where snapshot_id=v_snapshot.id;
 if not found then
   -- Conservative diagnostic; any unknown or recorded payment must block preparation.
   v_recon := public.gs_admin_discount_payment_reconciliation(p_order_id);
   if coalesce(v_recon->>'eligibility','') not in ('eligible','provisional_ready','no_payments') then
     raise exception 'Payment reconciliation not cleared: %',v_recon->>'eligibility';
   end if;
   insert into public.gs_locked_discount_payment_intents
    (snapshot_id,order_id,amount_due_iqd,created_by)
   values (v_snapshot.id,p_order_id,v_snapshot.amount_due_iqd,auth.uid())
   returning * into v_intent;
 end if;
 return jsonb_build_object('intent_id',v_intent.id,'snapshot_id',v_intent.snapshot_id,
  'order_id',v_intent.order_id,'amount_due_iqd',v_intent.amount_due_iqd,
  'status',v_intent.status,'payment_authorized',false,'money_moved',false);
end; $$;
revoke all on function public.gs_prepare_locked_discount_payment(bigint) from public,anon;
grant execute on function public.gs_prepare_locked_discount_payment(bigint) to authenticated;

create or replace function public.gs_reject_locked_discount_payment_intent_mutation()
returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'Payment preparation intents are immutable'; end; $$;
drop trigger if exists gs_locked_discount_payment_intents_immutable on public.gs_locked_discount_payment_intents;
create trigger gs_locked_discount_payment_intents_immutable before update or delete
on public.gs_locked_discount_payment_intents for each row
execute function public.gs_reject_locked_discount_payment_intent_mutation();
