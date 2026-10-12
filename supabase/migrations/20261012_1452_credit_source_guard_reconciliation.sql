-- Upgrade 1452: independent journal-source enforcement; protect against alternative definer writers.
-- Run on staging after diagnostic; no invoice settlement or Dashboard certification.
create or replace function public.gs_financial_credit_charge_source_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
declare
 q public.gs_motel_credit_verification_requests%rowtype;
 d public.gs_motel_food_payment_intent_drafts%rowtype;
 f public.gs_motel_food_finance_invoices%rowtype;
 a public.gs_credit_accounts%rowtype;
 c public.gs_credit_customers%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 r public.gs_motel_credit_barcode_registry%rowtype;
 v_count bigint;
 v_total numeric;
begin
 if new.event_kind <> 'charge' then return new; end if;
 if new.source_request_id is null or new.delta_outstanding_iqd <= 0 then
  raise exception 'Charge requires positive movement and verification request' using errcode='22023'; end if;
 select * into q from public.gs_motel_credit_verification_requests where id=new.source_request_id for share;
 if not found or q.status <> 'pending' or q.amount_iqd <> new.delta_outstanding_iqd then
  raise exception 'Credit charge request missing, cancelled or amount-mismatched' using errcode='22023'; end if;
 select * into d from public.gs_motel_food_payment_intent_drafts where id=q.intent_id for share;
 if not found or d.method <> 'credit' or d.status <> 'draft' or d.amount_iqd <> q.amount_iqd then
  raise exception 'Credit charge payment intent not exact active draft' using errcode='22023'; end if;
 select * into f from public.gs_motel_food_finance_invoices where id=d.finance_invoice_id for share;
 if not found or f.payment_status <> 'unpaid' or f.total_iqd <> q.amount_iqd or f.total_iqd<=0 or f.source_count<=0 then
  raise exception 'Credit charge invoice is not an exact positive unpaid source' using errcode='22023'; end if;
 select count(*),coalesce(sum(il.amount_iqd),0) into v_count,v_total
  from public.gs_motel_food_finance_invoice_lines il where il.finance_invoice_id=f.id;
 if v_count <> f.source_count or v_total <> f.total_iqd then
  raise exception 'Invoice registered source lines do not reconcile' using errcode='22023'; end if;
 if exists(select 1 from public.gs_motel_food_cash_settlements cash where cash.finance_invoice_id=f.id) then
  raise exception 'Invoice has an existing cash settlement' using errcode='23505'; end if;
 if exists(select 1 from public.gs_motel_food_payment_intent_drafts x where x.finance_invoice_id=f.id and x.id<>d.id) then
  raise exception 'Conflicting invoice payment draft' using errcode='23505'; end if;
 if exists(select 1 from public.gs_motel_credit_verification_requests x
    join public.gs_motel_food_payment_intent_drafts dx on dx.id=x.intent_id
    where dx.finance_invoice_id=f.id and x.id<>q.id and x.status='pending') then
  raise exception 'Competing pending credit verification request' using errcode='23505'; end if;
 if exists(select 1 from public.gs_credit_account_journal j
    join public.gs_motel_credit_verification_requests qr on qr.id=j.source_request_id
    join public.gs_motel_food_payment_intent_drafts dr on dr.id=qr.intent_id
    where dr.finance_invoice_id=f.id and j.event_kind='charge') then
  raise exception 'Invoice already charged in credit journal' using errcode='23505'; end if;
 select * into r from public.gs_motel_credit_barcode_registry where id=q.registry_id for share;
 if not found or r.account_status<>'active' then
  raise exception 'Active credit barcode registry required' using errcode='42501'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=q.registry_id for share;
 if not found or l.link_status <> 'verified' or l.verified_at is null or l.verified_by is null or l.account_id<>new.account_id then
  raise exception 'Credit registry-to-account identity is not independently verified' using errcode='42501'; end if;
 select * into a from public.gs_credit_accounts where id=new.account_id for share;
 if not found or a.account_reference is distinct from r.account_reference
    or a.account_status <> 'active' or a.currency <> 'IQD' then
  raise exception 'Credit account not verified against barcode and IQD status' using errcode='42501'; end if;
 select * into c from public.gs_credit_customers where id=a.customer_id for share;
 if not found or c.verification_status <> 'verified' then
  raise exception 'Credit account customer identity not verified' using errcode='42501'; end if;
 if new.outstanding_after_iqd <> a.outstanding_iqd or
    a.outstanding_iqd < new.delta_outstanding_iqd or
    a.outstanding_iqd > a.credit_limit_iqd then
  raise exception 'Journal charge does not match bounded account balance' using errcode='22023'; end if;
 if exists(select 1 from public.gs_credit_account_journal j
           where j.source_request_id=q.id and j.event_kind='charge') then
  raise exception 'Credit request already charged' using errcode='23505'; end if;
 return new;
end $$;
revoke all on function public.gs_financial_credit_charge_source_guard() from public,anon,authenticated;
-- Existing BEFORE INSERT trigger remains attached to the replaced function.
