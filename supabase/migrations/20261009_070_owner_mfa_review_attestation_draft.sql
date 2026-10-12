-- Upgrade 70: Owner-only MFA attestation for complimentary requests (DRAFT).
-- This records the genuine owner's review but DOES NOT approve a waiver,
-- mark gs_owner_guest_offers.status='verified', or change customer balances.
create table if not exists public.gs_owner_approval_principals (
 user_id uuid primary key references auth.users(id) on delete restrict,
 enabled boolean not null default true,
 provisioned_at timestamptz not null default now()
);
alter table public.gs_owner_approval_principals enable row level security;
revoke all on public.gs_owner_approval_principals from public,anon,authenticated;
-- Only a trusted backend/database administrator may provision owners.

create table if not exists public.gs_owner_guest_review_attestations (
 id bigint generated always as identity primary key,
 offer_id bigint not null references public.gs_owner_guest_offers(id) on delete restrict,
 owner_user_id uuid not null references auth.users(id),
 decision text not null check(decision in ('approve_for_financial_review','reject')),
 requested_amount_snapshot_iqd bigint not null check(requested_amount_snapshot_iqd>0),
 reason text,
 reviewed_at timestamptz not null default now(),
 unique(offer_id)
);
alter table public.gs_owner_guest_review_attestations enable row level security;
revoke all on public.gs_owner_guest_review_attestations from public,anon,authenticated;

create or replace function public.gs_owner_review_complimentary_request(
 p_offer_id bigint, p_decision text, p_reason text default null
) returns bigint
language plpgsql security definer set search_path='' as $$
declare
 v_offer public.gs_owner_guest_offers%rowtype;
 v_attestation_id bigint;
 v_aal text;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 v_aal:=coalesce(auth.jwt()->>'aal','');
 if v_aal<>'aal2' then
   raise exception 'Owner review requires MFA at AAL2';
 end if;
 if not exists (
   select 1 from public.gs_owner_approval_principals p
   where p.user_id=auth.uid() and p.enabled
 ) then raise exception 'Only a provisioned owner can review offers'; end if;
 if p_offer_id is null or p_decision not in
   ('approve_for_financial_review','reject') then
   raise exception 'Invalid owner decision'; end if;
 if p_reason is not null and length(p_reason)>500 then
   raise exception 'Reason too long'; end if;
 select * into v_offer from public.gs_owner_guest_offers
  where id=p_offer_id for update;
 if not found or v_offer.status<>'pending' then
   raise exception 'Pending offer not found'; end if;
 if v_offer.requested_amount_iqd is null
   or v_offer.requested_amount_iqd<=0
   or v_offer.order_id is null
   or v_offer.table_visit_id is null then
   raise exception 'Offer lacks valid order, visit or requested amount';
 end if;
 if exists(select 1 from public.gs_owner_guest_review_attestations a
   where a.offer_id=p_offer_id) then
   raise exception 'Offer already reviewed'; end if;
 insert into public.gs_owner_guest_review_attestations(
   offer_id,owner_user_id,decision,requested_amount_snapshot_iqd,reason)
 values(p_offer_id,auth.uid(),p_decision,
   v_offer.requested_amount_iqd,nullif(btrim(p_reason),''))
 returning id into v_attestation_id;
 if p_decision='reject' then
   update public.gs_owner_guest_offers set status='rejected'
   where id=p_offer_id;
 end if;
 -- Deliberately no status='verified', approved_by, or waiver posting.
 insert into public.gs_system_audit_events(
   actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','owner_offer_review_attested',
   p_offer_id::text,
   jsonb_build_object('attestation_id',v_attestation_id,
    'decision',p_decision,'requested_amount_iqd',
    v_offer.requested_amount_iqd,'aal','aal2'));
 return v_attestation_id;
end; $$;
revoke all on function public.gs_owner_review_complimentary_request(bigint,text,text)
 from public,anon;
grant execute on function public.gs_owner_review_complimentary_request(bigint,text,text)
 to authenticated;
-- WARNING: JWT AAL2 indicates session MFA, not fresh step-up.
-- A truly sensitive owner approval should require recent reauthentication,
-- and an independent ledger posting function before status can be verified.
