-- Credit posting hardening; no invoice settlement or certified Dashboard totals.
-- Staging verification and trigger compatibility required before enabling employee use.
-- Atomic credit account charge for an existing verified motel credit request.
-- IMPORTANT: a credit account charge is NOT invoice settlement, prepaid allocation or certified dashboard revenue.
create or replace function public.gs_financial_post_verified_credit_charge(p_request_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare q public.gs_motel_credit_verification_requests%rowtype;
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 a public.gs_credit_accounts%rowtype;
 c public.gs_credit_customers%rowtype;
 j public.gs_credit_account_journal%rowtype;
 v_new bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 or not coalesce(public.gs_can_access('credit_management','can_edit'),false) then
  raise exception 'Credit finance editor permissions required' using errcode='42501';
 end if;
 if p_request_id is null or p_idempotency_key is null or length(btrim(p_idempotency_key)) not between 12 and 200
 or p_idempotency_key <> btrim(p_idempotency_key) then
  raise exception 'Valid stable idempotency key and request required' using errcode='22023';
 end if;
 -- Serialize retries for the same request, even before the account lock is acquired.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 91287));
 select * into q from public.gs_motel_credit_verification_requests where id=p_request_id for update;
 if not found then raise exception 'Credit verification request not found' using errcode='P0002'; end if;
 if q.amount_iqd is null or q.amount_iqd <= 0 then raise exception 'Invalid source request amount' using errcode='22023'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=q.intent_id for update;
 if not found or d.method <> 'credit' or d.status <> 'draft' or d.amount_iqd <> q.amount_iqd then
  raise exception 'Credit draft and request mismatch'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id for update;
 if not found or f.payment_status <> 'unpaid' or f.total_iqd <> q.amount_iqd then
  raise exception 'Invoice not eligible for credit charge'; end if;
 if (select count(*) from public.gs_motel_credit_verification_requests r
    join public.gs_motel_food_payment_intent_drafts i on i.id=r.intent_id
    where i.finance_invoice_id=f.id and r.id<>q.id and r.status='pending')>0 then
  raise exception 'Multiple pending credit requests on invoice; reconcile before charging' using errcode='23505'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=q.registry_id for share;
 if not found or l.link_status <> 'verified' then raise exception 'Verified account registry link required' using errcode='42501'; end if;
 select * into a from public.gs_credit_accounts where id=l.account_id for update;
 if not found or a.account_status <> 'active' or a.currency <> 'IQD' then
  raise exception 'Active IQD account required' using errcode='42501'; end if;
 select * into c from public.gs_credit_customers where id=a.customer_id;
 if not found or c.verification_status <> 'verified' then raise exception 'Verified credit customer required' using errcode='42501'; end if;
 select * into j from public.gs_credit_account_journal where source_request_id=q.id and event_kind='charge';
 if found then
  if j.outstanding_after_iqd < j.delta_outstanding_iqd then
   raise exception 'Existing credit charge journal is inconsistent' using errcode='22023'; end if;
  if j.account_id <> a.id or j.delta_outstanding_iqd <> q.amount_iqd or
     j.external_idempotency_key <> p_idempotency_key then
   raise exception 'Request already charged under different terms' using errcode='23505'; end if;
  return pg_catalog.jsonb_build_object('journal_id',j.id,'already_posted',true,
    'charge_recorded',true,'invoice_settled',false,'prepaid_allocated',false,
    'dashboard_certified',false,'account_id',a.id,'amount_iqd',j.delta_outstanding_iqd);
 end if;
 if q.status <> 'pending' then raise exception 'Pending credit verification request required' using errcode='22023'; end if;
 if exists (select 1 from public.gs_credit_account_journal other_j
  join public.gs_motel_credit_verification_requests other_r on other_r.id=other_j.source_request_id
  join public.gs_motel_food_payment_intent_drafts other_d on other_d.id=other_r.intent_id
  where other_d.finance_invoice_id=f.id and other_j.event_kind='charge') then
  raise exception 'Invoice already has a credit journal charge' using errcode='23505'; end if;
 if exists(select 1 from public.gs_credit_account_journal where external_idempotency_key=p_idempotency_key) then
  raise exception 'Idempotency key already belongs to another event' using errcode='23505'; end if;
 if exists (select 1 from public.gs_credit_account_journal h
   where h.account_id=a.id and h.outstanding_after_iqd>a.credit_limit_iqd) then
  raise exception 'Historical credit journal exceeds account limit; reconciliation required' using errcode='22023'; end if;
 if a.outstanding_iqd > a.credit_limit_iqd - q.amount_iqd then
  raise exception 'Credit limit exceeded' using errcode='22023'; end if;
 v_new := a.outstanding_iqd + q.amount_iqd;
 update public.gs_credit_accounts set outstanding_iqd=v_new, version=version+1
  where id=a.id and outstanding_iqd=a.outstanding_iqd and version=a.version;
 if not found then raise exception 'Concurrent credit account version change' using errcode='40001'; end if;
 insert into public.gs_credit_account_journal(account_id,external_idempotency_key,event_kind,
 delta_outstanding_iqd,outstanding_after_iqd,source_request_id,created_by,note)
 values(a.id,p_idempotency_key,'charge',q.amount_iqd,v_new,q.id,auth.uid(),
 'Verified motel credit charge; invoice settlement remains unconfirmed') returning * into j;
 -- No invoice paid flag or unified payment ledger entry: those require separate authoritative reconciliation.
 return pg_catalog.jsonb_build_object('journal_id',j.id,'already_posted',false,
  'charge_recorded',true,'invoice_settled',false,'prepaid_allocated',false,
  'dashboard_certified',false,'account_id',a.id,'amount_iqd',q.amount_iqd);
end $$;
revoke all on function public.gs_financial_post_verified_credit_charge(uuid,text) from public,anon,authenticated;
grant execute on function public.gs_financial_post_verified_credit_charge(uuid,text) to authenticated;
