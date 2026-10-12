-- Upgrade 409: credit verification gate. No external balance/ownership authority connected.
create or replace function public.gs_staff_motel_credit_verification_gate(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare q public.gs_motel_credit_verification_requests%rowtype;
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_motel_credit_barcode_registry%rowtype;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized finance viewer required'; end if;
 select * into q from public.gs_motel_credit_verification_requests where id=p_request_id;
 if not found then raise exception 'Request not found'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=q.intent_id;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id;
 select * into a from public.gs_motel_credit_barcode_registry where id=q.registry_id;
 return query select 'request'::text,
 case when q.status='pending' then 'pass' else 'blocked' end::text,
 'Only pending verification requests are eligible for further checks'::text;
 return query select 'registered_identity'::text,
 case when a.account_status='active' then 'registry_active' else 'blocked' end::text,
 'Registry active status is not proof of ownership'::text;
 return query select 'invoice'::text,
 case when f.id is not null and f.payment_status='unpaid' and
 d.method='credit' and d.status='draft' and d.amount_iqd=q.amount_iqd
 and f.total_iqd=q.amount_iqd then 'pass' else 'blocked' end::text,
 'Credit draft and unpaid invoice must match request amount'::text;
 return query select 'account_ownership'::text,'unverified'::text,
 'No authoritative ownership verification has been connected'::text;
 return query select 'customer_consent'::text,'unverified'::text,
 'A review note is not a verified customer debit authorization'::text;
 return query select 'available_balance_and_limit'::text,'unverified'::text,
 'No authoritative available balance or credit limit check exists'::text;
 return query select 'atomic_debit'::text,'unavailable'::text,
 'No idempotent debit provider or reconciliation adapter exists'::text;
 return query select 'credit_settlement'::text,'blocked'::text,
 'Credit payment is blocked until every external verification and debit integration is implemented'::text;
end $$;
revoke all on function public.gs_staff_motel_credit_verification_gate(uuid) from public,anon;
grant execute on function public.gs_staff_motel_credit_verification_gate(uuid) to authenticated;
