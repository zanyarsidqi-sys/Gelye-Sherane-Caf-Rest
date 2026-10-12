-- Upgrade 381: finance-side unified invoice intake draft, NOT a posted invoice/payment.
-- Immutable source snapshot and idempotent guest-stay handoff.
create table if not exists public.gs_motel_food_unified_invoice_intake (
 id uuid primary key default extensions.gen_random_uuid(),
 food_invoice_id uuid not null unique references public.gs_motel_food_invoice_register(id),
 guest_session_id uuid not null unique references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 attestation_id uuid not null unique references public.gs_motel_food_finance_attestations(id),
 source_fingerprint text not null,
 source_count integer not null check(source_count>0),
 total_iqd bigint not null check(total_iqd>=0),
 intake_status text not null default 'draft' check(intake_status='draft'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_motel_food_unified_invoice_intake enable row level security;
revoke all on public.gs_motel_food_unified_invoice_intake from public,anon,authenticated;

create or replace function public.gs_staff_create_motel_food_invoice_intake(p_food_invoice_id uuid)
returns table(intake_id uuid, already_created boolean, source_count integer, total_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_header public.gs_motel_food_invoice_register%rowtype;
 v_att public.gs_motel_food_finance_attestations%rowtype;
 v_existing public.gs_motel_food_unified_invoice_intake%rowtype;
 v_state record; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and invoice editing permissions required';
 end if;
 select * into v_header from public.gs_motel_food_invoice_register
 where id=p_food_invoice_id for update;
 if not found then raise exception 'Food invoice register not found'; end if;
 select * into v_att from public.gs_motel_food_finance_attestations
 where food_invoice_id=p_food_invoice_id for update;
 if not found then raise exception 'Finance handoff attestation is required'; end if;
 select * into v_state from public.gs_staff_motel_food_attestation_status(p_food_invoice_id);
 if v_state.attestation_status is distinct from 'valid' then
  raise exception 'Attestation is stale or source reconciliation failed';
 end if;
 select * into v_existing from public.gs_motel_food_unified_invoice_intake
 where food_invoice_id=p_food_invoice_id for update;
 if found then
  if v_existing.guest_session_id is distinct from v_header.guest_session_id
  or v_existing.room_id is distinct from v_header.room_id
  or v_existing.attestation_id is distinct from v_att.id
  or v_existing.source_fingerprint is distinct from v_att.source_fingerprint
  or v_existing.source_count is distinct from v_header.source_count
  or v_existing.total_iqd is distinct from v_header.total_iqd then
   raise exception 'Existing intake draft conflicts with verified sources';
  end if;
  return query select v_existing.id,true,v_existing.source_count,v_existing.total_iqd;
  return;
 end if;
 insert into public.gs_motel_food_unified_invoice_intake
 (food_invoice_id,guest_session_id,room_id,attestation_id,source_fingerprint,source_count,total_iqd,created_by)
 values(v_header.id,v_header.guest_session_id,v_header.room_id,v_att.id,v_att.source_fingerprint,
 v_header.source_count,v_header.total_iqd,auth.uid()) returning id into v_id;
 return query select v_id,false,v_header.source_count,v_header.total_iqd;
end; $$;
revoke all on function public.gs_staff_create_motel_food_invoice_intake(uuid) from public,anon;
grant execute on function public.gs_staff_create_motel_food_invoice_intake(uuid) to authenticated;

create or replace function public.gs_staff_list_motel_food_invoice_intake()
returns table(intake_id uuid,food_invoice_id uuid,guest_session_id uuid,room_id uuid,
 source_count integer,total_iqd bigint,intake_status text,created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and invoice viewing permissions required';
 end if;
 return query select i.id,i.food_invoice_id,i.guest_session_id,i.room_id,
 i.source_count,i.total_iqd,i.intake_status,i.created_at
 from public.gs_motel_food_unified_invoice_intake i order by i.created_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_food_invoice_intake() from public,anon;
grant execute on function public.gs_staff_list_motel_food_invoice_intake() to authenticated;
