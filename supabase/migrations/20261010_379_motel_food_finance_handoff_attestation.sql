-- Upgrade 379: auditable finance handoff attestation; NOT a unified invoice or payment.
create table if not exists public.gs_motel_food_finance_attestations (
 id uuid primary key default extensions.gen_random_uuid(),
 food_invoice_id uuid not null unique references public.gs_motel_food_invoice_register(id),
 source_fingerprint text not null,
 source_count integer not null check(source_count>0),
 total_iqd bigint not null check(total_iqd>=0),
 attested_by uuid not null references auth.users(id),
 attested_at timestamptz not null default now(),
 note text not null check(length(trim(note)) between 5 and 500)
);
alter table public.gs_motel_food_finance_attestations enable row level security;
revoke all on public.gs_motel_food_finance_attestations from public,anon,authenticated;

create or replace function public.gs_staff_attest_motel_food_finance_handoff(p_invoice_id uuid,p_note text)
returns table(attestation_id uuid,already_attested boolean,source_count integer,total_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_header public.gs_motel_food_invoice_register%rowtype;
 v_readiness record; v_fingerprint text; v_existing public.gs_motel_food_finance_attestations%rowtype; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Invoice editing and motel viewing permissions required';
 end if;
 if length(trim(coalesce(p_note,''))) not between 5 and 500 then
  raise exception 'A finance review note (5-500 characters) is required';
 end if;
 select * into v_header from public.gs_motel_food_invoice_register h where h.id=p_invoice_id for update;
 if not found then raise exception 'Food invoice register not found'; end if;
 select * into v_readiness from public.gs_staff_motel_food_invoice_readiness(p_invoice_id);
 if v_readiness.readiness_status <> 'source_verified' then
  raise exception 'Source reconciliation required before handoff attestation';
 end if;
 select md5(coalesce(string_agg(l.source_order_id::text||':'||l.source_ledger_id::text||':'||
  l.reservation_id::text||':'||l.amount_iqd::text,'|' order by l.source_order_id),'') )
 into v_fingerprint from public.gs_motel_food_invoice_register_lines l where l.invoice_id=p_invoice_id;
 select * into v_existing from public.gs_motel_food_finance_attestations a
 where a.food_invoice_id=p_invoice_id for update;
 if found then
  if v_existing.source_fingerprint<>v_fingerprint or v_existing.source_count<>v_header.source_count
   or v_existing.total_iqd<>v_header.total_iqd then
   raise exception 'Existing finance attestation is stale; manual reconciliation required';
  end if;
  return query select v_existing.id,true,v_existing.source_count,v_existing.total_iqd;
  return;
 end if;
 insert into public.gs_motel_food_finance_attestations
 (food_invoice_id,source_fingerprint,source_count,total_iqd,attested_by,note)
 values(p_invoice_id,v_fingerprint,v_header.source_count,v_header.total_iqd,auth.uid(),trim(p_note))
 returning id into v_id;
 return query select v_id,false,v_header.source_count,v_header.total_iqd;
end; $$;
revoke all on function public.gs_staff_attest_motel_food_finance_handoff(uuid,text) from public,anon;
grant execute on function public.gs_staff_attest_motel_food_finance_handoff(uuid,text) to authenticated;
