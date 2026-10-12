-- Upgrade 403: auditable credit verification requests; no balance authority or debit.
create table public.gs_motel_credit_verification_requests (
 id uuid primary key default extensions.gen_random_uuid(),
 intent_id uuid not null references public.gs_motel_food_payment_intent_drafts(id),
 registry_id uuid not null references public.gs_motel_credit_barcode_registry(id),
 amount_iqd bigint not null check(amount_iqd>0),
 status text not null default 'pending' check(status in ('pending','cancelled')),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 cancelled_by uuid references auth.users(id),
 cancelled_at timestamptz,
 cancellation_reason text,
 unique(intent_id,registry_id)
);
create unique index gs_motel_credit_one_pending_request
 on public.gs_motel_credit_verification_requests(intent_id) where status='pending';
alter table public.gs_motel_credit_verification_requests enable row level security;
revoke all on public.gs_motel_credit_verification_requests from public,anon,authenticated;

create function public.gs_staff_request_motel_credit_verification(
 p_intent_id uuid,p_barcode text)
returns table(request_id uuid, request_status text, amount_iqd bigint, account_label text)
language plpgsql security definer set search_path='' as $$
declare
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_motel_credit_barcode_registry%rowtype;
 q public.gs_motel_credit_verification_requests%rowtype;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Finance editor required'; end if;
 if p_barcode is null or length(btrim(p_barcode)) not between 6 and 128
 then raise exception 'Invalid barcode'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts
 where id=p_intent_id for update;
 if not found or d.method<>'credit' or d.status<>'draft'
 then raise exception 'Active credit draft required'; end if;
 select * into f from public.gs_motel_food_finance_invoices
 where id=d.finance_invoice_id for update;
 if not found or f.payment_status<>'unpaid'
 or f.total_iqd is distinct from d.amount_iqd
 then raise exception 'Invoice is not eligible'; end if;
 select * into a from public.gs_motel_credit_barcode_registry
 where barcode_sha256=encode(extensions.digest(btrim(p_barcode),'sha256'),'hex');
 if not found or a.account_status<>'active'
 then raise exception 'Active registered credit identity required'; end if;
 select * into q from public.gs_motel_credit_verification_requests
 where intent_id=d.id and status='pending';
 if found then
  if q.registry_id<>a.id or q.amount_iqd<>d.amount_iqd
  then raise exception 'Another verification request is already pending'; end if;
 else
  insert into public.gs_motel_credit_verification_requests
   (intent_id,registry_id,amount_iqd,requested_by)
  values(d.id,a.id,d.amount_iqd,auth.uid()) returning * into q;
 end if;
 return query select q.id,q.status,q.amount_iqd,a.display_label;
end $$;
revoke all on function public.gs_staff_request_motel_credit_verification(uuid,text) from public,anon;
grant execute on function public.gs_staff_request_motel_credit_verification(uuid,text) to authenticated;

create function public.gs_staff_list_motel_credit_verifications(p_intent_id uuid)
returns table(request_id uuid,request_status text,amount_iqd bigint,
 account_label text,requested_by uuid,requested_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Finance viewer required'; end if;
 return query select q.id,q.status,q.amount_iqd,a.display_label,
 q.requested_by,q.requested_at
 from public.gs_motel_credit_verification_requests q
 join public.gs_motel_credit_barcode_registry a on a.id=q.registry_id
 where q.intent_id=p_intent_id order by q.requested_at desc;
end $$;
revoke all on function public.gs_staff_list_motel_credit_verifications(uuid) from public,anon;
grant execute on function public.gs_staff_list_motel_credit_verifications(uuid) to authenticated;
