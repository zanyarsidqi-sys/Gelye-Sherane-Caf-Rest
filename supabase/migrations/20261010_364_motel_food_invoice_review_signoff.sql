-- Upgrade 364: audited employee sign-off for food-only invoice drafts.
-- This is NOT an official invoice or payment. Does not alter existing ledgers.
create table if not exists public.gs_motel_food_draft_reviews (
 id uuid primary key default extensions.gen_random_uuid(),
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 reviewed_by uuid not null references auth.users(id),
 reviewed_at timestamptz not null default now(),
 order_count bigint not null check(order_count > 0),
 amount_iqd numeric not null check(amount_iqd >= 0),
 note text not null default '',
 unique(guest_session_id)
);
alter table public.gs_motel_food_draft_reviews enable row level security;
revoke all on public.gs_motel_food_draft_reviews from public,anon,authenticated;

create or replace function public.gs_staff_review_motel_food_draft(p_guest_session_id uuid,p_note text default '')
returns table(review_id uuid, reviewed_order_count bigint, reviewed_amount_iqd numeric)
language plpgsql security definer set search_path = '' as $$
declare v_count bigint; v_amount numeric; v_blocked bigint; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false)
 then raise exception 'Not authorized'; end if;
 if p_guest_session_id is null then raise exception 'Guest session required'; end if;
 if length(coalesce(p_note,'')) > 500 then raise exception 'Note too long'; end if;
 -- Serialize reviews for the same guest stay.
 perform 1 from public.gs_motel_guest_stay_sessions where id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 select count(*),coalesce(sum(l.amount_iqd),0),
 count(*) filter (where o.status <> 'delivered' or o.delivered_at is null
  or o.total_iqd <> l.amount_iqd or l.payment_status <> 'unpaid' or l.invoice_id is not null
  or (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
      where i.request_id=o.id) <> l.amount_iqd)
 into v_count,v_amount,v_blocked
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id and o.guest_session_id=p_guest_session_id;
 if v_count=0 or v_blocked>0 then raise exception 'Food draft has no eligible orders or requires reconciliation'; end if;
 insert into public.gs_motel_food_draft_reviews(guest_session_id,reviewed_by,order_count,amount_iqd,note)
 values(p_guest_session_id,auth.uid(),v_count,v_amount,coalesce(p_note,''))
 on conflict(guest_session_id) do nothing returning id into v_id;
 if v_id is null then raise exception 'Draft already reviewed; re-review requires a separate authorized workflow'; end if;
 return query select v_id,v_count,v_amount;
end; $$;
revoke all on function public.gs_staff_review_motel_food_draft(uuid,text) from public;
grant execute on function public.gs_staff_review_motel_food_draft(uuid,text) to authenticated;

create or replace function public.gs_staff_motel_food_draft_review_status()
returns table(guest_session_id uuid,reviewed_at timestamptz,reviewed_by uuid,
 reviewed_order_count bigint,reviewed_amount_iqd numeric,current_order_count bigint,
 current_amount_iqd numeric,changed_since_review boolean)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 return query select r.guest_session_id,r.reviewed_at,r.reviewed_by,r.order_count,r.amount_iqd,
 count(l.id)::bigint,coalesce(sum(l.amount_iqd),0)::numeric,
 (r.order_count<>count(l.id) or r.amount_iqd<>coalesce(sum(l.amount_iqd),0))
 from public.gs_motel_food_draft_reviews r
 left join public.gs_motel_food_billing_ledger l on l.guest_session_id=r.guest_session_id
 group by r.id order by r.reviewed_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_draft_review_status() from public;
grant execute on function public.gs_staff_motel_food_draft_review_status() to authenticated;
