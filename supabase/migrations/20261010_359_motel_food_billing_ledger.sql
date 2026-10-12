-- Upgrade 359: idempotent delivered-food billing staging ledger.
-- Not an official invoice, payment, or accommodation charge.
create table if not exists public.gs_motel_food_billing_ledger (
 id uuid primary key default extensions.gen_random_uuid(),
 request_id uuid not null unique references public.gs_motel_guest_food_requests(id),
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 amount_iqd bigint not null check(amount_iqd >= 0),
 posted_at timestamptz not null default now(),
 invoice_id uuid,
 payment_status text not null default 'unpaid' check(payment_status in ('unpaid','partially_paid','paid')),
 check(invoice_id is null)
);
alter table public.gs_motel_food_billing_ledger enable row level security;
revoke all on public.gs_motel_food_billing_ledger from public,anon,authenticated;

create or replace function public.gs_stage_delivered_motel_food()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.status='delivered' and old.status is distinct from new.status then
  if new.delivered_at is null then raise exception 'Delivered food requires delivery timestamp'; end if;
  if (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
      where i.request_id=new.id) <> new.total_iqd then
   raise exception 'Food request amount does not match line items'; end if;
  insert into public.gs_motel_food_billing_ledger(request_id,guest_session_id,room_id,amount_iqd)
  values(new.id,new.guest_session_id,new.room_id,new.total_iqd)
  on conflict(request_id) do nothing;
 end if;
 return new;
end; $$;
drop trigger if exists gs_stage_delivered_motel_food_trigger on public.gs_motel_guest_food_requests;
create trigger gs_stage_delivered_motel_food_trigger
 after update of status on public.gs_motel_guest_food_requests
 for each row execute function public.gs_stage_delivered_motel_food();

-- Backfill previously delivered orders, once per request. Existing data with inconsistent
-- totals must be investigated rather than silently charged.
insert into public.gs_motel_food_billing_ledger(request_id,guest_session_id,room_id,amount_iqd,posted_at)
select o.id,o.guest_session_id,o.room_id,o.total_iqd,coalesce(o.delivered_at,now())
from public.gs_motel_guest_food_requests o
where o.status='delivered' and o.delivered_at is not null
 and o.total_iqd=(select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i where i.request_id=o.id)
on conflict(request_id) do nothing;

create or replace function public.gs_staff_motel_food_billing_ledger()
returns table(request_id uuid,room_label text,room_name text,amount_iqd bigint,
 posted_at timestamptz,payment_status text,invoice_linked boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false) then
  raise exception 'Not authorized'; end if;
 return query select l.request_id,r.room_label,r.room_name,l.amount_iqd,l.posted_at,
 l.payment_status,(l.invoice_id is not null)
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_room_qr r on r.id=l.room_id
 order by l.posted_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_billing_ledger() from public;
grant execute on function public.gs_staff_motel_food_billing_ledger() to authenticated;
