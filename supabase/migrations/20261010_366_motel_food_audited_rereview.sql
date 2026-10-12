-- Upgrade 366: controlled, audited re-review of a changed food-only draft.
-- No official invoice, payment, or credit movement is created.
create table if not exists public.gs_motel_food_draft_review_history (
 id uuid primary key default extensions.gen_random_uuid(),
 guest_session_id uuid not null references public.gs_motel_guest_stay_sessions(id),
 previous_reviewed_by uuid not null references auth.users(id),
 previous_reviewed_at timestamptz not null,
 previous_order_count bigint not null,
 previous_amount_iqd numeric not null,
 replaced_by uuid not null references auth.users(id),
 replaced_at timestamptz not null default now(),
 reason text not null check(length(trim(reason)) between 5 and 500)
);
alter table public.gs_motel_food_draft_review_history enable row level security;
revoke all on public.gs_motel_food_draft_review_history from public,anon,authenticated;

create or replace function public.gs_staff_rereview_motel_food_draft(p_guest_session_id uuid,p_reason text)
returns table(review_id uuid,reviewed_order_count bigint,reviewed_amount_iqd numeric)
language plpgsql security definer set search_path = '' as $$
declare v_previous public.gs_motel_food_draft_reviews%rowtype;
 v_count bigint; v_amount numeric; v_bad bigint; v_missing bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false)
 then raise exception 'Not authorized'; end if;
 if p_guest_session_id is null then raise exception 'Guest stay required'; end if;
 if length(trim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'Reason must be 5-500 characters'; end if;
 perform 1 from public.gs_motel_guest_stay_sessions where id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 select * into v_previous from public.gs_motel_food_draft_reviews
 where guest_session_id=p_guest_session_id for update;
 if not found then raise exception 'No existing review; use initial review'; end if;
 select count(*) into v_missing from public.gs_motel_guest_food_requests o
 where o.guest_session_id=p_guest_session_id and o.status='delivered'
 and not exists(select 1 from public.gs_motel_food_billing_ledger l where l.request_id=o.id);
 if v_missing>0 then raise exception 'Missing ledger entries: %',v_missing; end if;
 select count(*),coalesce(sum(l.amount_iqd),0),
 count(*) filter(where o.status<>'delivered' or o.delivered_at is null
  or o.total_iqd<>l.amount_iqd or l.payment_status<>'unpaid' or l.invoice_id is not null
  or o.guest_session_id<>l.guest_session_id or o.room_id<>l.room_id
  or (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
      where i.request_id=o.id)<>l.amount_iqd)
 into v_count,v_amount,v_bad from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id;
 if v_count=0 or v_bad>0 then raise exception 'Food draft requires reconciliation'; end if;
 if v_previous.order_count=v_count and v_previous.amount_iqd=v_amount then
  raise exception 'Existing review is current; no re-review needed'; end if;
 insert into public.gs_motel_food_draft_review_history(
 guest_session_id,previous_reviewed_by,previous_reviewed_at,previous_order_count,
 previous_amount_iqd,replaced_by,reason)
 values(p_guest_session_id,v_previous.reviewed_by,v_previous.reviewed_at,
 v_previous.order_count,v_previous.amount_iqd,auth.uid(),trim(p_reason));
 update public.gs_motel_food_draft_reviews set reviewed_by=auth.uid(),reviewed_at=now(),
 order_count=v_count,amount_iqd=v_amount,note=trim(p_reason)
 where id=v_previous.id;
 return query select v_previous.id,v_count,v_amount;
end; $$;
revoke all on function public.gs_staff_rereview_motel_food_draft(uuid,text) from public;
grant execute on function public.gs_staff_rereview_motel_food_draft(uuid,text) to authenticated;
