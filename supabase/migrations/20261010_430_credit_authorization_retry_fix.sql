-- Upgrade 430: fix re-request after cancellation/expiry.
-- Upgrade 421 unique index permanently blocked same-review same-invoice retries,
-- even when the old request was cancelled or expired. Upgrade 429's invoice-wide
-- trigger already guards concurrent active requests using advisory locks.
-- Preserve history; allow new requests only when no live request exists.
drop index if exists public.gs_credit_authorization_request_duplicate_guard;
create index if not exists gs_credit_authorization_review_invoice_history_idx
 on public.gs_credit_customer_authorization_requests(review_id,invoice_reference,requested_at desc);

create or replace function public.gs_staff_request_credit_customer_authorization(
 p_review_id uuid,p_invoice_reference text,p_amount_iqd bigint,p_channel text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 v_invoice_id uuid;
 new_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_invoice_reference is null or length(btrim(p_invoice_reference)) not between 8 and 120
 or p_amount_iqd is null or p_amount_iqd<=0
 or p_channel is null or p_channel not in ('in_person','phone','sms','email','other')
 or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Valid invoice reference, amount, channel and note required'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=p_review_id for update;
 if not found or v.status='rejected' then raise exception 'Eligible identity review required'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=v.registry_id for update;
 if not found or l.account_id<>v.account_id or l.link_status<>'pending'
 then raise exception 'Matching pending link required'; end if;
 select * into a from public.gs_credit_accounts where id=v.account_id for update;
 if not found or a.account_status<>'pending' then raise exception 'Pending account required'; end if;
 -- Require a real unpaid invoice and the exact amount at request creation.
 begin
   v_invoice_id := btrim(p_invoice_reference)::uuid;
 exception when invalid_text_representation then
   raise exception 'Invoice reference must be a valid motel food invoice UUID';
 end;
 select * into f from public.gs_motel_food_finance_invoices
 where id=v_invoice_id for update;
 if not found or f.payment_status <> 'unpaid' or f.total_iqd <> p_amount_iqd then
   raise exception 'Unpaid invoice with matching amount required';
 end if;
 insert into public.gs_credit_customer_authorization_requests
 (review_id,registry_id,account_id,invoice_reference,amount_iqd,channel,note,requested_by)
 values(v.id,v.registry_id,v.account_id,v_invoice_id::text,p_amount_iqd,p_channel,btrim(p_note),auth.uid())
 returning id into new_id;
 -- Invoice-wide trigger from Upgrade 429 serializes concurrent inserts and
 -- rejects another still-outstanding, unexpired request.
 if new_id is null then raise exception 'Authorization request could not be created'; end if;
 return new_id;
end $$;

