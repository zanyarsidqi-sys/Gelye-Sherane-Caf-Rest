-- Finance identity evidence workflow. No payment posting, invoice status changes or certified amounts.
-- Candidate links are not verified crosswalks. Independent documentary evidence is required.
create table if not exists public.gs_financial_crosswalk_evidence (
 id uuid primary key default extensions.gen_random_uuid(),
 cafe_order_id bigint not null references public.gs_orders(id) on delete restrict,
 motel_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id) on delete restrict,
 evidence_reference text not null check(length(btrim(evidence_reference)) between 12 and 240),
 evidence_sha256 text not null check(evidence_sha256 ~ '^[0-9a-f]{64}$'),
 evidence_description text not null check(length(btrim(evidence_description)) between 20 and 1000),
 submitted_by uuid not null references auth.users(id),
 submitted_at timestamptz not null default now(),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_state text not null default 'pending' check(review_state in ('pending','rejected','reviewed_unverified')),
 review_note text,
 unique(cafe_order_id,motel_invoice_id),
 check ((reviewed_by is null and reviewed_at is null and review_state='pending') or
        (reviewed_by is not null and reviewed_at is not null and review_state<>'pending')),
 check(reviewed_by is null or reviewed_by<>submitted_by)
);
create index if not exists gs_financial_crosswalk_invoice_idx on public.gs_financial_crosswalk_evidence(motel_invoice_id);
alter table public.gs_financial_crosswalk_evidence enable row level security;
revoke all on public.gs_financial_crosswalk_evidence from public,anon,authenticated;

create or replace function public.gs_financial_submit_crosswalk_evidence(
 p_order_id bigint,p_invoice_id uuid,p_reference text,p_sha256 text,p_description text)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_id uuid; v_order public.gs_orders%rowtype; v_invoice public.gs_motel_food_finance_invoices%rowtype;
 v_bridge public.gs_motel_finance_source_bridge%rowtype; v_total bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_edit'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Payments editor and motel viewer required' using errcode='42501'; end if;
 if p_order_id is null or p_order_id<=0 or p_invoice_id is null or p_reference is null
 or length(btrim(p_reference)) not between 12 and 240 or p_sha256 is null
 or p_sha256 !~ '^[0-9a-f]{64}$' or p_description is null
 or length(btrim(p_description)) not between 20 and 1000
 then raise exception 'Valid IDs and independently retrievable evidence required' using errcode='22023'; end if;
 select * into v_order from public.gs_orders where id=p_order_id for share;
 if not found or not v_order.is_motel or v_order.status='cancelled' then
 raise exception 'Eligible motel cafe order required' using errcode='22023'; end if;
 select * into v_invoice from public.gs_motel_food_finance_invoices where id=p_invoice_id for share;
 if not found then raise exception 'Motel invoice not found' using errcode='P0002'; end if;
 select * into v_bridge from public.gs_motel_finance_source_bridge where finance_invoice_id=p_invoice_id for share;
 if not found or v_bridge.legacy_order_id is not null or v_bridge.amount_iqd<>v_invoice.total_iqd
 or v_bridge.source_fingerprint<>v_invoice.source_fingerprint
 then raise exception 'Consistent unmapped invoice bridge required' using errcode='22023'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total from public.gs_order_items where order_id=p_order_id;
 if v_total<=0 or v_total>v_invoice.total_iqd then
 raise exception 'Order amount outside invoice bounds' using errcode='22023'; end if;
 insert into public.gs_financial_crosswalk_evidence(cafe_order_id,motel_invoice_id,evidence_reference,evidence_sha256,evidence_description,submitted_by)
 values(p_order_id,p_invoice_id,btrim(p_reference),p_sha256,btrim(p_description),auth.uid())
 on conflict(cafe_order_id,motel_invoice_id) do nothing returning id into v_id;
 if v_id is null then raise exception 'Evidence already submitted for this order/invoice pair' using errcode='23505'; end if;
 return v_id;
end $$;
revoke all on function public.gs_financial_submit_crosswalk_evidence(bigint,uuid,text,text,text) from public,anon;
grant execute on function public.gs_financial_submit_crosswalk_evidence(bigint,uuid,text,text,text) to authenticated;

create or replace function public.gs_financial_review_crosswalk_evidence(p_evidence_id uuid,p_accept_for_review boolean,p_note text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v public.gs_financial_crosswalk_evidence%rowtype; v_state text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_edit'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Finance editor and motel viewer required' using errcode='42501'; end if;
 if p_evidence_id is null or p_accept_for_review is null or p_note is null
 or length(btrim(p_note)) not between 20 and 1000
 then raise exception 'Evidence ID, decision and substantive review note required' using errcode='22023'; end if;
 select * into v from public.gs_financial_crosswalk_evidence where id=p_evidence_id for update;
 if not found then raise exception 'Evidence not found' using errcode='P0002'; end if;
 if v.review_state<>'pending' then raise exception 'Evidence already reviewed' using errcode='23505'; end if;
 if v.submitted_by=auth.uid() then raise exception 'Independent reviewer required' using errcode='42501'; end if;
 v_state:=case when p_accept_for_review then 'reviewed_unverified' else 'rejected' end;
 update public.gs_financial_crosswalk_evidence set reviewed_by=auth.uid(),reviewed_at=now(),
 review_state=v_state,review_note=btrim(p_note) where id=p_evidence_id;
 return jsonb_build_object('evidence_id',p_evidence_id,'review_state',v_state,
 'identity_verified',false,'settlement_confirmed',false,'verified_complete',false);
end $$;
revoke all on function public.gs_financial_review_crosswalk_evidence(uuid,boolean,text) from public,anon;
grant execute on function public.gs_financial_review_crosswalk_evidence(uuid,boolean,text) to authenticated;

create or replace function public.gs_financial_crosswalk_evidence_status(p_order_id bigint,p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.gs_financial_crosswalk_evidence%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('payments_management','can_view'),false)
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Finance and motel viewers required' using errcode='42501'; end if;
 if p_order_id is null or p_order_id<=0 or p_invoice_id is null then raise exception 'Valid IDs required' using errcode='22023'; end if;
 select * into v from public.gs_financial_crosswalk_evidence
 where cafe_order_id=p_order_id and motel_invoice_id=p_invoice_id;
 return jsonb_build_object('order_id',p_order_id,'invoice_id',p_invoice_id,
 'evidence_exists',v.id is not null,'evidence_id',v.id,'review_state',v.review_state,
 'independent_review',v.reviewed_by is not null and v.reviewed_by<>v.submitted_by,
 'identity_verified',false,'prepaid_allocation_confirmed',false,
 'credit_debit_confirmed',false,'verified_complete',false,'certified_unpaid_iqd',null,
 'generated_at',now(),
 'warning','Documentary review is not an authoritative source-system crosswalk or payment confirmation.');
end $$;
revoke all on function public.gs_financial_crosswalk_evidence_status(bigint,uuid) from public,anon;
grant execute on function public.gs_financial_crosswalk_evidence_status(bigint,uuid) to authenticated;
