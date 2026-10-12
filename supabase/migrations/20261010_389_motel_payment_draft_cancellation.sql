-- Upgrade 389: controlled payment-draft cancellation; never settles money.
-- Cancelled drafts are retained for audit, while a new draft can be prepared.
alter table public.gs_motel_food_payment_intent_drafts
 drop constraint if exists gs_motel_food_payment_intent_drafts_status_check;
alter table public.gs_motel_food_payment_intent_drafts
 add constraint gs_motel_food_payment_intent_drafts_status_check
 check (status in ('draft','cancelled'));
alter table public.gs_motel_food_payment_intent_drafts
 add column if not exists cancelled_by uuid references auth.users(id),
 add column if not exists cancelled_at timestamptz,
 add column if not exists cancellation_reason text;
drop index if exists public.gs_motel_food_one_active_payment_draft;
create unique index gs_motel_food_one_active_payment_draft
 on public.gs_motel_food_payment_intent_drafts(finance_invoice_id)
 where status='draft';
-- Idempotency keys must not be reused across cancelled attempts.
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
 where d.finance_invoice_id=v.id and d.status='draft' for update;
 if found then
  if v_existing.idempotency_key is distinct from p_idempotency_key
    or v_existing.method is distinct from p_method
    or v_existing.amount_iqd is distinct from v.total_iqd then
    raise exception 'Active payment draft already exists; cancel it before preparing another';
  end if;
  return query select v_existing.id,true,v_existing.amount_iqd,v_existing.method;return;
 end if;
 if exists(select 1 from public.gs_motel_food_payment_intent_drafts d
  where d.finance_invoice_id=v.id and d.idempotency_key=p_idempotency_key) then
  raise exception 'This payment attempt was cancelled; use a new idempotency key';
 end if;
 insert into public.gs_motel_food_payment_intent_drafts
 (finance_invoice_id,method,amount_iqd,idempotency_key,created_by)
 values(v.id,p_method,v.total_iqd,p_idempotency_key,auth.uid()) returning id into v_id;
 return query select v_id,false,v.total_iqd,p_method;
end; $$;
revoke all on function public.gs_staff_prepare_motel_food_payment(uuid,text,uuid) from public,anon;
grant execute on function public.gs_staff_prepare_motel_food_payment(uuid,text,uuid) to authenticated;

create or replace function public.gs_staff_cancel_motel_food_payment_draft(
 p_intent_id uuid,p_reason text)
returns table(intent_id uuid,cancelled_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_payment_intent_drafts%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Finance editing permissions required';
 end if;
 if length(btrim(coalesce(p_reason,''))) < 5 or length(p_reason)>500 then
  raise exception 'Cancellation reason must be 5 to 500 characters';
 end if;
 select * into v from public.gs_motel_food_payment_intent_drafts d
 where d.id=p_intent_id for update;
 if not found then raise exception 'Payment draft not found'; end if;
 if v.status<>'draft' then raise exception 'Only active drafts may be cancelled'; end if;
 update public.gs_motel_food_payment_intent_drafts d
 set status='cancelled',cancelled_by=auth.uid(),cancelled_at=now(),
 cancellation_reason=btrim(p_reason)
 where d.id=v.id;
 return query select v.id,now();
end; $$;
revoke all on function public.gs_staff_cancel_motel_food_payment_draft(uuid,text) from public,anon;
grant execute on function public.gs_staff_cancel_motel_food_payment_draft(uuid,text) to authenticated;

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
