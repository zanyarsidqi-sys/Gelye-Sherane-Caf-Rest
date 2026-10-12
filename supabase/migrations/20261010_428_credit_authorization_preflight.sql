-- Read-only readiness preflight. No customer consent, debit or approval is created.
create or replace function public.gs_staff_credit_authorization_preflight(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path='' as $$
declare q public.gs_credit_customer_authorization_requests%rowtype;
 v public.gs_credit_identity_review_requests%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 invoice_uuid uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management view permission required'; end if;
 select * into q from public.gs_credit_customer_authorization_requests where id=p_request_id;
 if not found then raise exception 'Authorization request not found'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=q.review_id;
 select * into l from public.gs_credit_account_registry_links where registry_id=q.registry_id;
 select * into a from public.gs_credit_accounts where id=q.account_id;
 begin invoice_uuid:=q.invoice_reference::uuid;
 exception when invalid_text_representation then invoice_uuid:=null; end;
 if invoice_uuid is not null then
  select * into f from public.gs_motel_food_finance_invoices where id=invoice_uuid;
 end if;
 return query select 'request_window'::text,
  case when q.status='requested' and q.expires_at>statement_timestamp() then 'valid' else 'blocked' end::text,
  'Request must remain pending and unexpired'::text;
 return query select 'identity_review'::text,
  case when v.id is not null and v.registry_id=q.registry_id and v.account_id=q.account_id
   and v.status='reviewed' then 'reviewed_not_verified' else 'blocked' end::text,
  'Staff evidence review is not authoritative customer identity verification'::text;
 return query select 'registry_link'::text,
  case when l.registry_id=q.registry_id and l.account_id=q.account_id and l.link_status='pending'
  then 'pending_not_verified' else 'blocked' end::text,
  'A pending registry link cannot be used to charge credit'::text;
 return query select 'credit_account'::text,
  case when a.id=q.account_id and a.account_status='pending' then 'pending_not_active'
  else 'blocked' end::text,
  'Credit account activation is not implemented'::text;
 return query select 'invoice'::text,
  case when f.id is not null and f.payment_status='unpaid' and f.total_iqd=q.amount_iqd
  then 'matched' else 'blocked' end::text,
  'Invoice must exist, be unpaid and match the requested amount'::text;
 return query select 'customer_authentication'::text,'not_implemented'::text,
  'No authenticated customer authorization endpoint exists'::text;
 return query select 'customer_consent'::text,'not_implemented'::text,
  'No customer consent evidence has been recorded'::text;
 return query select 'credit_debit'::text,'blocked'::text,
  'No money movement is permitted by this preflight'::text;
end $$;
revoke all on function public.gs_staff_credit_authorization_preflight(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_preflight(uuid) to authenticated;
