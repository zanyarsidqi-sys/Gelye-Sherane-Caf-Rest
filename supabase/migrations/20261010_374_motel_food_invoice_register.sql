-- Upgrade 374: atomic food-only invoice register. No cash, credit, or legacy invoice writes.
-- This is an isolated food invoice register, NOT the shared accounting invoice module.
create table if not exists public.gs_motel_food_invoice_register (
 id uuid primary key default extensions.gen_random_uuid(),
 guest_session_id uuid not null unique references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 total_iqd bigint not null check (total_iqd>=0),
 source_count integer not null check (source_count>0),
 posted_by uuid not null references auth.users(id),
 posted_at timestamptz not null default now()
);
create table if not exists public.gs_motel_food_invoice_register_lines (
 id uuid primary key default extensions.gen_random_uuid(),
 invoice_id uuid not null references public.gs_motel_food_invoice_register(id),
 reservation_id uuid not null unique references public.gs_motel_food_invoice_source_reservations(id),
 source_order_id uuid not null unique references public.gs_motel_guest_food_requests(id),
 source_ledger_id uuid not null unique references public.gs_motel_food_billing_ledger(id),
 amount_iqd bigint not null check(amount_iqd>=0)
);
alter table public.gs_motel_food_invoice_register enable row level security;
alter table public.gs_motel_food_invoice_register_lines enable row level security;
revoke all on public.gs_motel_food_invoice_register from public,anon,authenticated;
revoke all on public.gs_motel_food_invoice_register_lines from public,anon,authenticated;

create or replace function public.gs_staff_post_motel_food_invoice_register(p_guest_session_id uuid)
returns table(invoice_id uuid, source_count integer, total_iqd bigint, already_posted boolean)
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_room uuid; v_count integer; v_total bigint; v_existing public.gs_motel_food_invoice_register%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel and invoice editing permissions required';
 end if;
 -- Serialize with the existing approval and reservation workflows.
 select s.room_id into v_room from public.gs_motel_guest_stay_sessions s
 where s.id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 -- Re-evaluate source fingerprints and line totals at posting time.
 create temporary table if not exists pg_temp.gs_invoice_expected_374
 (order_id uuid,ledger_id uuid,room_id uuid,amount bigint,review_id uuid,fingerprint text)
 on commit drop;
 truncate pg_temp.gs_invoice_expected_374;
 insert into pg_temp.gs_invoice_expected_374
 select c.source_order_id,c.source_ledger_id,c.room_id,c.amount_iqd,c.review_id,c.review_fingerprint
 from public.gs_staff_motel_food_invoice_crosswalk_preview(p_guest_session_id) c;
 select count(*)::integer,coalesce(sum(e.amount),0)::bigint into v_count,v_total
 from pg_temp.gs_invoice_expected_374 e;
 if v_count=0 then raise exception 'No eligible verified charges'; end if;
 if exists(select 1 from pg_temp.gs_invoice_expected_374 e where e.room_id<>v_room) then
  raise exception 'Guest room mismatch'; end if;
 -- Exact set equality: no missing, mismatched, or unexpected reservations.
 if exists(
  select 1 from pg_temp.gs_invoice_expected_374 e
  left join public.gs_motel_food_invoice_source_reservations r
   on r.source_order_id=e.order_id and r.guest_session_id=p_guest_session_id
  where r.id is null or r.source_ledger_id<>e.ledger_id or r.room_id<>e.room_id
   or r.amount_iqd<>e.amount or r.review_id<>e.review_id
   or r.review_fingerprint<>e.fingerprint
 ) or exists(
  select 1 from public.gs_motel_food_invoice_source_reservations r
  where r.guest_session_id=p_guest_session_id
   and not exists(select 1 from pg_temp.gs_invoice_expected_374 e where e.order_id=r.source_order_id)
 ) then raise exception 'Reservations require reconciliation before posting'; end if;
 select * into v_existing from public.gs_motel_food_invoice_register h
 where h.guest_session_id=p_guest_session_id for update;
 if found then
  if v_existing.room_id<>v_room or v_existing.total_iqd<>v_total or v_existing.source_count<>v_count
   or (select count(*) from public.gs_motel_food_invoice_register_lines l where l.invoice_id=v_existing.id)<>v_count
   or exists(select 1 from pg_temp.gs_invoice_expected_374 e
    left join public.gs_motel_food_invoice_register_lines l on l.source_order_id=e.order_id
    where l.id is null or l.invoice_id<>v_existing.id or l.source_ledger_id<>e.ledger_id
      or l.amount_iqd<>e.amount) then
   raise exception 'Previously posted invoice differs; manual financial reconciliation required';
  end if;
  return query select v_existing.id,v_count,v_total,true;
  return;
 end if;
 insert into public.gs_motel_food_invoice_register(guest_session_id,room_id,total_iqd,source_count,posted_by)
 values(p_guest_session_id,v_room,v_total,v_count,auth.uid()) returning id into v_id;
 insert into public.gs_motel_food_invoice_register_lines(invoice_id,reservation_id,source_order_id,source_ledger_id,amount_iqd)
 select v_id,r.id,e.order_id,e.ledger_id,e.amount
 from pg_temp.gs_invoice_expected_374 e
 join public.gs_motel_food_invoice_source_reservations r on r.source_order_id=e.order_id
  and r.guest_session_id=p_guest_session_id;
 if (select count(*) from public.gs_motel_food_invoice_register_lines l where l.invoice_id=v_id)<>v_count then
  raise exception 'Incomplete invoice register posting';
 end if;
 return query select v_id,v_count,v_total,false;
end; $$;
revoke all on function public.gs_staff_post_motel_food_invoice_register(uuid) from public,anon;
grant execute on function public.gs_staff_post_motel_food_invoice_register(uuid) to authenticated;

create or replace function public.gs_staff_list_motel_food_invoice_register()
returns table(invoice_id uuid,guest_session_id uuid,room_id uuid,total_iqd bigint,source_count integer,posted_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and invoice viewing permissions required';
 end if;
 return query select h.id,h.guest_session_id,h.room_id,h.total_iqd,h.source_count,h.posted_at
 from public.gs_motel_food_invoice_register h order by h.posted_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_food_invoice_register() from public,anon;
grant execute on function public.gs_staff_list_motel_food_invoice_register() to authenticated;
