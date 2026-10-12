-- Upgrade 405: credit backend readiness is diagnostic only; never an approval.
-- Catalog checks do not establish business correctness or available balance.
create or replace function public.gs_staff_motel_credit_backend_readiness(p_intent_id uuid)
returns table(check_name text, check_status text, detail text)
language plpgsql security definer set search_path='' as $$
declare d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 n integer;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized finance viewer required'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=p_intent_id;
 if not found or d.method<>'credit' or d.status<>'draft'
 then raise exception 'Active credit draft required'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id;
 return query select 'invoice'::text,
 case when f.id is not null and f.payment_status='unpaid' and f.total_iqd=d.amount_iqd
 then 'pass' else 'blocked' end::text,
 'Must remain unpaid with the same draft amount'::text;
 return query select 'barcode_registry'::text,
 case when to_regclass('public.gs_motel_credit_barcode_registry') is not null then 'present' else 'missing' end::text,
 'Barcode registry is only an identity reference, not account ownership proof'::text;
 select count(*) into n from public.gs_motel_credit_verification_requests q
 where q.intent_id=d.id and q.status='pending';
 return query select 'verification_request'::text,
 case when n=1 then 'pending' else 'missing' end::text,
 'Pending requests are not approved credit payments'::text;
 return query select 'authoritative_balance'::text,'unverified'::text,
 'No deployed authoritative credit account/balance/limit adapter has been validated'::text;
 return query select 'ownership_and_consent'::text,'unverified'::text,
 'Barcode match alone does not verify account owner or consent'::text;
 return query select 'atomic_debit_ledger'::text,'unverified'::text,
 'No transactional, idempotent credit debit integration is configured'::text;
 return query select 'payment_eligible'::text,'blocked'::text,
 'Credit settlement must remain disabled until authoritative integration is implemented and tested'::text;
end $$;
revoke all on function public.gs_staff_motel_credit_backend_readiness(uuid) from public,anon;
grant execute on function public.gs_staff_motel_credit_backend_readiness(uuid) to authenticated;
