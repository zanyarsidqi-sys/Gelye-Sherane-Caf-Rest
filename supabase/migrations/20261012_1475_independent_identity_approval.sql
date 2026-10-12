-- Upgrade 1475: independent second-person approval for invoice/order mapping.
-- Approval is evidence only. It cannot pay an invoice or write to the unified ledger.
create table if not exists public.gs_motel_cafe_identity_approvals (
 id uuid primary key default extensions.gen_random_uuid(),
 mapping_id uuid not null unique references public.gs_motel_cafe_order_identity_evidence(id) on delete restrict,
 approved_by uuid not null references auth.users(id),
 approval_reference text not null check (length(trim(approval_reference)) between 12 and 256),
 approval_note text not null check (length(trim(approval_note)) between 20 and 1000),
 approved_at timestamptz not null default now()
);
alter table public.gs_motel_cafe_identity_approvals enable row level security;
revoke all on public.gs_motel_cafe_identity_approvals from public,anon,authenticated;
create or replace function public.gs_approve_motel_cafe_identity(
 p_mapping_id uuid, p_reference text, p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_mapping public.gs_motel_cafe_order_identity_evidence%rowtype;
 v_approval public.gs_motel_cafe_identity_approvals%rowtype;
begin
 if auth.uid() is null or
 not coalesce(public.gs_can_access('motel_orders','can_view'),false) or
 not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Authorized finance reviewer required' using errcode='42501'; end if;
 if p_mapping_id is null or length(trim(coalesce(p_reference,''))) not between 12 and 256
 or length(trim(coalesce(p_note,''))) not between 20 and 1000
 then raise exception 'Independent evidence reference and review note required' using errcode='22023'; end if;
 select * into v_mapping from public.gs_motel_cafe_order_identity_evidence
 where id=p_mapping_id for update;
 if not found then raise exception 'Mapping not found' using errcode='P0002'; end if;
 if v_mapping.verified_by=auth.uid() then
 raise exception 'Second-person review required' using errcode='42501'; end if;
 select * into v_approval from public.gs_motel_cafe_identity_approvals
 where mapping_id=p_mapping_id for update;
 if found then
  return jsonb_build_object('approval_id',v_approval.id,'already_approved',true,
  'mapping_id',p_mapping_id,'invoice_settled',false,'unified_ledger_posted',false,
  'dashboard_certified',false);
 end if;
 insert into public.gs_motel_cafe_identity_approvals
 (mapping_id,approved_by,approval_reference,approval_note)
 values(p_mapping_id,auth.uid(),trim(p_reference),trim(p_note)) returning * into v_approval;
 return jsonb_build_object('approval_id',v_approval.id,'already_approved',false,
 'mapping_id',p_mapping_id,'invoice_settled',false,'unified_ledger_posted',false,
 'dashboard_certified',false);
end $$;
revoke all on function public.gs_approve_motel_cafe_identity(uuid,text,text) from public,anon;
grant execute on function public.gs_approve_motel_cafe_identity(uuid,text,text) to authenticated;
create or replace function public.gs_identity_approval_immutable()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Identity approvals are append-only'; end $$;
drop trigger if exists gs_identity_approval_immutable on public.gs_motel_cafe_identity_approvals;
create trigger gs_identity_approval_immutable before update or delete
on public.gs_motel_cafe_identity_approvals for each row
execute function public.gs_identity_approval_immutable();
