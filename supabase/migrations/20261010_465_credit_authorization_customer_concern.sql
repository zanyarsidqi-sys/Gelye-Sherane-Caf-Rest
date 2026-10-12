-- Customer can flag an invoice authorization they do not recognize.
-- This is NOT consent, approval, verification, or a debit.
create table if not exists public.gs_credit_authorization_customer_concerns (
 id uuid primary key default gen_random_uuid(),
 authorization_request_id uuid not null references public.gs_credit_customer_authorization_requests(id),
 customer_id uuid not null references public.gs_credit_customers(id),
 auth_user_id uuid not null references auth.users(id),
 reason text not null check (char_length(btrim(reason)) between 10 and 1000),
 created_at timestamptz not null default statement_timestamp(),
 unique(authorization_request_id,auth_user_id)
);
alter table public.gs_credit_authorization_customer_concerns enable row level security;
revoke all on public.gs_credit_authorization_customer_concerns from public,anon,authenticated;
create or replace function public.gs_credit_report_authorization_concern(p_invoice_reference text,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_request uuid; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then raise exception 'Reason must be 10 to 1000 characters'; end if;
 select b.customer_id into v_customer from public.gs_credit_customer_auth_bindings b
 where b.auth_user_id=auth.uid() and b.status='verified' and b.verified_at is not null and b.verified_by is not null limit 1;
 if v_customer is null then raise exception 'Verified identity required'; end if;
 if exists(select 1 from public.gs_credit_identity_customer_safety_holds h
 join public.gs_credit_identity_onboarding_requests o on o.id=h.onboarding_request_id
 where o.customer_id=v_customer or h.auth_user_id=auth.uid()) then raise exception 'Identity safety hold active'; end if;
 select q.id into v_request from public.gs_credit_customer_authorization_requests q
 join public.gs_credit_accounts a on a.id=q.account_id
 where a.customer_id=v_customer and q.invoice_reference=p_invoice_reference
 order by q.requested_at desc,q.id desc limit 1;
 if v_request is null then raise exception 'Authorization request not available'; end if;
 insert into public.gs_credit_authorization_customer_concerns(authorization_request_id,customer_id,auth_user_id,reason)
 values(v_request,v_customer,auth.uid(),btrim(p_reason))
 on conflict(authorization_request_id,auth_user_id) do update set reason=excluded.reason
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_credit_report_authorization_concern(text,text) from public,anon;
grant execute on function public.gs_credit_report_authorization_concern(text,text) to authenticated;
