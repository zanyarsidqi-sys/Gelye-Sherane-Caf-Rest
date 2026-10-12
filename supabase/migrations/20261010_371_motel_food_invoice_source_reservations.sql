-- Upgrade 371: durable, unique invoice-source reservation records.
-- Deliberately does NOT post official invoices, allocate payments, or change food ledger invoice_id.
create table if not exists public.gs_motel_food_invoice_source_reservations (
 id uuid primary key default extensions.gen_random_uuid(),
 source_order_id uuid not null unique references public.gs_motel_guest_food_requests(id),
 source_ledger_id uuid not null unique references public.gs_motel_food_billing_ledger(id),
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 room_id uuid not null references public.gs_motel_room_qr(id),
 amount_iqd bigint not null check (amount_iqd >= 0),
 review_id uuid not null references public.gs_motel_food_draft_reviews(id),
 review_fingerprint text not null,
 reserved_by uuid not null references auth.users(id),
 reserved_at timestamptz not null default now(),
 -- A future invoice writer must add a separate audited transaction-safe posting step.
 check(length(review_fingerprint)>0)
);
alter table public.gs_motel_food_invoice_source_reservations enable row level security;
revoke all on public.gs_motel_food_invoice_source_reservations from public,anon,authenticated;

create or replace function public.gs_staff_reserve_motel_food_invoice_sources(p_guest_session_id uuid)
returns table(source_order_id uuid, source_ledger_id uuid, amount_iqd bigint, reservation_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_count integer; v_existing integer; v_expected integer;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false)
    or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false) then
  raise exception 'Motel and invoice edit permissions required';
 end if;
 -- Serialize concurrent reservations for the same guest stay.
 perform 1 from public.gs_motel_guest_stay_sessions s where s.id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 -- The manifest enforces fingerprint, room, status, and ledger integrity.
 create temporary table if not exists pg_temp.gs_invoice_sources_371 (
  order_id uuid, ledger_id uuid, room_id uuid, amount bigint, review_id uuid, fingerprint text
 ) on commit drop;
 truncate pg_temp.gs_invoice_sources_371;
 insert into pg_temp.gs_invoice_sources_371
 select c.source_order_id,c.source_ledger_id,c.room_id,c.amount_iqd,c.review_id,c.review_fingerprint
 from public.gs_staff_motel_food_invoice_crosswalk_preview(p_guest_session_id) c;
 select count(*) into v_expected from pg_temp.gs_invoice_sources_371;
 if v_expected=0 then raise exception 'No eligible food charges'; end if;
 -- Existing reservations must match exactly; never overwrite or silently relink.
 if exists (
  select 1 from pg_temp.gs_invoice_sources_371 s
  join public.gs_motel_food_invoice_source_reservations r on r.source_order_id=s.order_id or r.source_ledger_id=s.ledger_id
  where r.source_order_id<>s.order_id or r.source_ledger_id<>s.ledger_id
    or r.guest_session_id<>p_guest_session_id or r.room_id<>s.room_id
    or r.amount_iqd<>s.amount or r.review_id<>s.review_id
    or r.review_fingerprint<>s.fingerprint
 ) then raise exception 'Existing invoice source reservation differs; manual reconciliation required'; end if;
 insert into public.gs_motel_food_invoice_source_reservations
  (source_order_id,source_ledger_id,guest_session_id,room_id,amount_iqd,review_id,review_fingerprint,reserved_by)
 select s.order_id,s.ledger_id,p_guest_session_id,s.room_id,s.amount,s.review_id,s.fingerprint,auth.uid()
 from pg_temp.gs_invoice_sources_371 s
 on conflict(source_order_id) do nothing;
 select count(*) into v_count from public.gs_motel_food_invoice_source_reservations r
 join pg_temp.gs_invoice_sources_371 s on s.order_id=r.source_order_id
 where r.guest_session_id=p_guest_session_id and r.source_ledger_id=s.ledger_id
 and r.amount_iqd=s.amount and r.review_id=s.review_id and r.review_fingerprint=s.fingerprint;
 if v_count<>v_expected then raise exception 'Invoice source reservation incomplete; transaction rolled back'; end if;
 return query select r.source_order_id,r.source_ledger_id,r.amount_iqd,r.id
 from public.gs_motel_food_invoice_source_reservations r
 join pg_temp.gs_invoice_sources_371 s on s.order_id=r.source_order_id
 order by r.source_order_id;
end; $$;
revoke all on function public.gs_staff_reserve_motel_food_invoice_sources(uuid) from public,anon;
grant execute on function public.gs_staff_reserve_motel_food_invoice_sources(uuid) to authenticated;
