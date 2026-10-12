-- Upgrade 421: invoice-specific customer authorization request. This is NOT consent.
create table if not exists public.gs_credit_customer_authorization_requests (
 id uuid primary key default gen_random_uuid(),
 review_id uuid not null references public.gs_credit_identity_review_requests(id),
 registry_id uuid not null references public.gs_credit_account_registry_links(registry_id),
 account_id uuid not null references public.gs_credit_accounts(id),
 invoice_reference text not null check(length(btrim(invoice_reference)) between 8 and 120),
 amount_iqd bigint not null check(amount_iqd>0),
 channel text not null check(channel in ('in_person','phone','sms','email','other')),
 status text not null default 'requested' check(status='requested'),
 note text not null check(length(btrim(note)) between 10 and 1000),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now()
);
create unique index if not exists gs_credit_authorization_request_duplicate_guard
 on public.gs_credit_customer_authorization_requests(review_id,invoice_reference,amount_iqd);
create index if not exists gs_credit_authorization_requests_review_idx
 on public.gs_credit_customer_authorization_requests(review_id,requested_at desc);
alter table public.gs_credit_customer_authorization_requests enable row level security;
revoke all on public.gs_credit_customer_authorization_requests from public,anon,authenticated;
create or replace function public.gs_staff_request_credit_customer_authorization(
 p_review_id uuid,p_invoice_reference text,p_amount_iqd bigint,p_channel text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
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
 insert into public.gs_credit_customer_authorization_requests
 (review_id,registry_id,account_id,invoice_reference,amount_iqd,channel,note,requested_by)
 values(v.id,v.registry_id,v.account_id,btrim(p_invoice_reference),p_amount_iqd,p_channel,btrim(p_note),auth.uid())
 on conflict(review_id,invoice_reference,amount_iqd) do nothing returning id into new_id;
 if new_id is null then raise exception 'Authorization request already exists for this invoice and amount'; end if;
 return new_id;
end $$;
revoke all on function public.gs_staff_request_credit_customer_authorization(uuid,text,bigint,text,text) from public,anon;
grant execute on function public.gs_staff_request_credit_customer_authorization(uuid,text,bigint,text,text) to authenticated;
create or replace function public.gs_staff_list_credit_customer_authorization_requests(p_review_id uuid)
returns table(invoice_reference text,amount_iqd bigint,channel text,status text,
 note text,requested_by uuid,requested_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select q.invoice_reference,q.amount_iqd,q.channel,q.status,q.note,q.requested_by,q.requested_at
 from public.gs_credit_customer_authorization_requests q where q.review_id=p_review_id
 order by q.requested_at desc,q.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_customer_authorization_requests(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_customer_authorization_requests(uuid) to authenticated;
