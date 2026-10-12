-- Upgrade 1473: independently evidenced UUID invoice -> bigint cafe order mapping.
-- A mapping is NOT a payment, settlement, invoice paid-state, or dashboard certification.
-- A mapping may only be registered when both source identities are explicitly known.
create table if not exists public.gs_motel_cafe_order_identity_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id) on delete restrict,
  cafe_order_id bigint not null unique references public.gs_orders(id) on delete restrict,
  evidence_reference text not null check (length(trim(evidence_reference)) between 12 and 256),
  evidence_description text not null check (length(trim(evidence_description)) between 20 and 1000),
  verified_by uuid not null references auth.users(id),
  verified_at timestamptz not null default now(),
  check (cafe_order_id > 0)
);
alter table public.gs_motel_cafe_order_identity_evidence enable row level security;
revoke all on public.gs_motel_cafe_order_identity_evidence from public, anon, authenticated;
create or replace function public.gs_register_motel_cafe_order_identity(
 p_invoice_id uuid, p_order_id bigint, p_evidence_reference text, p_evidence_description text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_existing public.gs_motel_cafe_order_identity_evidence%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Authorized finance employee required' using errcode='42501'; end if;
 if p_invoice_id is null or p_order_id is null or p_order_id<=0
 or length(trim(coalesce(p_evidence_reference,''))) not between 12 and 256
 or length(trim(coalesce(p_evidence_description,''))) not between 20 and 1000
 then raise exception 'Explicit identities and auditable evidence required' using errcode='22023'; end if;
 -- Lock both actual source rows; never infer a UUID/bigint conversion.
 perform 1 from public.gs_motel_food_finance_invoices where id=p_invoice_id for update;
 if not found then raise exception 'Invoice identity missing' using errcode='P0002'; end if;
 perform 1 from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Cafe order identity missing' using errcode='P0002'; end if;
 select * into v_existing from public.gs_motel_cafe_order_identity_evidence
 where finance_invoice_id=p_invoice_id or cafe_order_id=p_order_id for update;
 if found then
  if v_existing.finance_invoice_id<>p_invoice_id or v_existing.cafe_order_id<>p_order_id
  then raise exception 'Conflicting source identity' using errcode='23505'; end if;
  return jsonb_build_object('mapping_id',v_existing.id,'already_registered',true,
   'invoice_id',p_invoice_id,'cafe_order_id',p_order_id,
   'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
 end if;
 insert into public.gs_motel_cafe_order_identity_evidence
 (finance_invoice_id,cafe_order_id,evidence_reference,evidence_description,verified_by)
 values(p_invoice_id,p_order_id,trim(p_evidence_reference),trim(p_evidence_description),auth.uid())
 returning * into v_existing;
 return jsonb_build_object('mapping_id',v_existing.id,'already_registered',false,
 'invoice_id',p_invoice_id,'cafe_order_id',p_order_id,
 'invoice_settled',false,'unified_ledger_posted',false,'dashboard_certified',false);
end $$;
revoke all on function public.gs_register_motel_cafe_order_identity(uuid,bigint,text,text) from public,anon;
grant execute on function public.gs_register_motel_cafe_order_identity(uuid,bigint,text,text) to authenticated;
create or replace function public.gs_motel_cafe_identity_immutable()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Audited identity mapping is append-only'; end $$;
drop trigger if exists gs_motel_cafe_identity_immutable on public.gs_motel_cafe_order_identity_evidence;
create trigger gs_motel_cafe_identity_immutable before update or delete
on public.gs_motel_cafe_order_identity_evidence for each row
execute function public.gs_motel_cafe_identity_immutable();
