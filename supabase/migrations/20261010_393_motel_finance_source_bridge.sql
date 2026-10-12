-- Upgrade 393: durable source bridge without fabricating legacy numeric orders.
-- No settlement writer, legacy ledger posting, or payment status changes.
create table if not exists public.gs_motel_finance_source_bridge (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null unique references public.gs_motel_food_finance_invoices(id) on delete restrict,
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 source_fingerprint text not null,
 amount_iqd bigint not null check (amount_iqd >= 0),
 -- Must remain NULL until a separately reviewed, provable legacy mapping exists.
 legacy_order_id bigint unique references public.gs_orders(id) on delete restrict,
 mapping_status text not null default 'unmapped' check(mapping_status='unmapped'),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 constraint gs_motel_bridge_no_unverified_legacy_link check (legacy_order_id is null)
);
alter table public.gs_motel_finance_source_bridge enable row level security;
revoke all on public.gs_motel_finance_source_bridge from public,anon,authenticated;

create or replace function public.gs_staff_register_motel_finance_source(p_invoice_id uuid)
returns table(bridge_id uuid, already_registered boolean, mapping_status text, amount_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v public.gs_motel_food_finance_invoices%rowtype;
 v_bridge public.gs_motel_finance_source_bridge%rowtype;
 v_check record;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and finance editing permissions required';
 end if;
 select * into v from public.gs_motel_food_finance_invoices where id=p_invoice_id for update;
 if not found then raise exception 'Finance invoice not found'; end if;
 select * into v_check from public.gs_staff_check_motel_food_finance_invoice(p_invoice_id);
 -- The reconciliation function is required to succeed before any bridge is created.
 if v_check.check_status is distinct from 'matched' then
  raise exception 'Finance invoice reconciliation must be verified before registration';
 end if;
 select * into v_bridge from public.gs_motel_finance_source_bridge where finance_invoice_id=v.id for update;
 if found then
  if v_bridge.guest_session_id<>v.guest_session_id or v_bridge.room_id<>v.room_id
    or v_bridge.source_fingerprint<>v.source_fingerprint or v_bridge.amount_iqd<>v.total_iqd
    or v_bridge.legacy_order_id is not null then
   raise exception 'Existing bridge does not match current invoice';
  end if;
  return query select v_bridge.id,true,v_bridge.mapping_status,v_bridge.amount_iqd;
  return;
 end if;
 insert into public.gs_motel_finance_source_bridge
 (finance_invoice_id,guest_session_id,room_id,source_fingerprint,amount_iqd,created_by)
 values(v.id,v.guest_session_id,v.room_id,v.source_fingerprint,v.total_iqd,auth.uid())
 returning * into v_bridge;
 return query select v_bridge.id,false,v_bridge.mapping_status,v_bridge.amount_iqd;
end; $$;
revoke all on function public.gs_staff_register_motel_finance_source(uuid) from public,anon;
grant execute on function public.gs_staff_register_motel_finance_source(uuid) to authenticated;
