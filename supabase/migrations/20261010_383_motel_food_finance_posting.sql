-- Upgrade 383: transaction-safe finance invoice posting in a dedicated motel-food namespace.
-- Not connected to legacy invoices, settlement, credit or payment tables.
create table if not exists public.gs_motel_food_finance_invoices (
 id uuid primary key default extensions.gen_random_uuid(),
 intake_id uuid not null unique references public.gs_motel_food_unified_invoice_intake(id),
 food_invoice_id uuid not null unique references public.gs_motel_food_invoice_register(id),
 guest_session_id uuid not null unique references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 source_fingerprint text not null,
 source_count integer not null check(source_count>0),
 total_iqd bigint not null check(total_iqd>=0),
 payment_status text not null default 'unpaid' check(payment_status='unpaid'),
 posted_by uuid not null references auth.users(id),
 posted_at timestamptz not null default now()
);
create table if not exists public.gs_motel_food_finance_invoice_lines (
 id uuid primary key default extensions.gen_random_uuid(),
 finance_invoice_id uuid not null references public.gs_motel_food_finance_invoices(id),
 source_register_line_id uuid not null unique references public.gs_motel_food_invoice_register_lines(id),
 source_order_id uuid not null unique references public.gs_motel_guest_food_requests(id),
 amount_iqd bigint not null check(amount_iqd>=0)
);
alter table public.gs_motel_food_finance_invoices enable row level security;
alter table public.gs_motel_food_finance_invoice_lines enable row level security;
revoke all on public.gs_motel_food_finance_invoices from public,anon,authenticated;
revoke all on public.gs_motel_food_finance_invoice_lines from public,anon,authenticated;

create or replace function public.gs_staff_post_motel_food_finance_invoice(p_food_invoice_id uuid)
returns table(finance_invoice_id uuid, already_posted boolean, source_count integer, total_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_intake public.gs_motel_food_unified_invoice_intake%rowtype;
 v_existing public.gs_motel_food_finance_invoices%rowtype;
 v_id uuid; v_check record; v_count integer; v_total bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel viewing and finance editing permissions required';
 end if;
 -- Lock intake row: serializes concurrent posting for the same source.
 select * into v_intake from public.gs_motel_food_unified_invoice_intake
 where food_invoice_id=p_food_invoice_id for update;
 if not found then raise exception 'Finance intake draft is required'; end if;
 select * into v_check from public.gs_staff_motel_food_intake_integrity(p_food_invoice_id);
 if v_check.intake_status is distinct from 'verified' then
  raise exception 'Finance intake integrity failed: %',coalesce(v_check.details,'unknown');
 end if;
 select count(*)::integer,coalesce(sum(l.amount_iqd),0)::bigint into v_count,v_total
 from public.gs_motel_food_invoice_register_lines l where l.invoice_id=p_food_invoice_id;
 if v_count<>v_intake.source_count or v_total<>v_intake.total_iqd then
  raise exception 'Source invoice lines do not reconcile';
 end if;
 select * into v_existing from public.gs_motel_food_finance_invoices
 where intake_id=v_intake.id for update;
 if found then
  if v_existing.food_invoice_id is distinct from p_food_invoice_id
   or v_existing.guest_session_id is distinct from v_intake.guest_session_id
   or v_existing.room_id is distinct from v_intake.room_id
   or v_existing.source_fingerprint is distinct from v_intake.source_fingerprint
   or v_existing.source_count<>v_count or v_existing.total_iqd<>v_total
   or (select count(*) from public.gs_motel_food_finance_invoice_lines l
       where l.finance_invoice_id=v_existing.id)<>v_count
   or exists(select 1 from public.gs_motel_food_invoice_register_lines r
     left join public.gs_motel_food_finance_invoice_lines l on l.source_register_line_id=r.id
     where r.invoice_id=p_food_invoice_id and
       (l.finance_invoice_id is distinct from v_existing.id
        or l.source_order_id is distinct from r.source_order_id
        or l.amount_iqd is distinct from r.amount_iqd)) then
    raise exception 'Existing finance invoice differs from verified source';
  end if;
  return query select v_existing.id,true,v_count,v_total; return;
 end if;
 insert into public.gs_motel_food_finance_invoices
 (intake_id,food_invoice_id,guest_session_id,room_id,source_fingerprint,source_count,total_iqd,posted_by)
 values(v_intake.id,p_food_invoice_id,v_intake.guest_session_id,v_intake.room_id,
 v_intake.source_fingerprint,v_count,v_total,auth.uid()) returning id into v_id;
 insert into public.gs_motel_food_finance_invoice_lines
 (finance_invoice_id,source_register_line_id,source_order_id,amount_iqd)
 select v_id,l.id,l.source_order_id,l.amount_iqd
 from public.gs_motel_food_invoice_register_lines l where l.invoice_id=p_food_invoice_id;
 if (select count(*) from public.gs_motel_food_finance_invoice_lines l
     where l.finance_invoice_id=v_id)<>v_count then
  raise exception 'Finance invoice posting incomplete';
 end if;
 return query select v_id,false,v_count,v_total;
end; $$;
revoke all on function public.gs_staff_post_motel_food_finance_invoice(uuid) from public,anon;
grant execute on function public.gs_staff_post_motel_food_finance_invoice(uuid) to authenticated;
