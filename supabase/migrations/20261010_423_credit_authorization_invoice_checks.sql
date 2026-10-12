-- Upgrade 423: bind authorization-request review to an actual motel food invoice.
-- Read-only and fail-closed; it does NOT accept consent or authorize a charge.
create or replace function public.gs_staff_credit_authorization_invoice_checks(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare q public.gs_credit_customer_authorization_requests%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 invoice_id uuid;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Credit and invoice viewer permissions required'; end if;
 select * into q from public.gs_credit_customer_authorization_requests
 where id=p_request_id;
 if not found then raise exception 'Authorization request not found'; end if;
 return query select 'request_status'::text,
 case when q.status='requested' then 'pending' else 'blocked' end::text,
 'A request is not customer authorization'::text;
 begin invoice_id:=q.invoice_reference::uuid;
 exception when invalid_text_representation then invoice_id:=null; end;
 if invoice_id is not null then
   select * into f from public.gs_motel_food_finance_invoices where id=invoice_id;
 end if;
 return query select 'invoice_reference'::text,
 case when f.id is not null then 'matched' else 'blocked' end::text,
 'Reference must be the UUID of a real motel food finance invoice'::text;
 return query select 'invoice_amount'::text,
 case when f.id is not null and f.total_iqd=q.amount_iqd then 'matched' else 'blocked' end::text,
 'Requested amount must match invoice total'::text;
 return query select 'invoice_payment_status'::text,
 case when f.id is not null and f.payment_status='unpaid' then 'unpaid' else 'blocked' end::text,
 'Already paid or missing invoices cannot be authorized'::text;
 return query select 'customer_identity'::text,'unverified'::text,
 'Customer authentication and verified identity are not connected'::text;
 return query select 'customer_consent'::text,'unverified'::text,
 'No customer-facing consent confirmation has been implemented'::text;
 return query select 'credit_charge'::text,'blocked'::text,
 'No credit debit or settlement is authorized by these checks'::text;
end $$;
revoke all on function public.gs_staff_credit_authorization_invoice_checks(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_invoice_checks(uuid) to authenticated;
