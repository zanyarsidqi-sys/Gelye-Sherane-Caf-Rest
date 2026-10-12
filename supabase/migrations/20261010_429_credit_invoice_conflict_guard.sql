-- Upgrade 429: prevent multiple outstanding credit authorization requests for one invoice.
-- No customer consent, credit approval, or financial posting is performed.
create or replace function public.gs_credit_invoice_request_conflicts(p_invoice_reference text)
returns table(request_id uuid, review_id uuid, requested_at timestamptz, expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select q.id,q.review_id,q.requested_at,q.expires_at
 from public.gs_credit_customer_authorization_requests q
 where q.invoice_reference=p_invoice_reference and q.status='requested'
 and q.expires_at>statement_timestamp()
 order by q.requested_at desc limit 100;
end $$;
revoke all on function public.gs_credit_invoice_request_conflicts(text) from public,anon;
grant execute on function public.gs_credit_invoice_request_conflicts(text) to authenticated;

-- Locking serializes requests for the same invoice even across different identity reviews.
create or replace function public.gs_credit_guard_invoice_authorization_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.invoice_reference,429));
 if exists(select 1 from public.gs_credit_customer_authorization_requests q
  where q.invoice_reference=new.invoice_reference and q.status='requested'
  and q.expires_at>statement_timestamp())
 then raise exception 'Another unexpired authorization request exists for this invoice'; end if;
 return new;
end $$;
revoke all on function public.gs_credit_guard_invoice_authorization_insert() from public,anon,authenticated;
drop trigger if exists gs_credit_invoice_request_conflict_guard on public.gs_credit_customer_authorization_requests;
create trigger gs_credit_invoice_request_conflict_guard before insert
on public.gs_credit_customer_authorization_requests
for each row execute function public.gs_credit_guard_invoice_authorization_insert();
