-- Upgrade 368: identity-level food draft review fingerprint. No invoice or payment posting.
alter table public.gs_motel_food_draft_reviews add column if not exists order_fingerprint text;
alter table public.gs_motel_food_draft_review_history add column if not exists previous_order_fingerprint text;
-- Older reviews have no fingerprint; they are deliberately treated as stale until audited re-review.
create or replace function public.gs_staff_review_motel_food_draft(p_guest_session_id uuid,p_note text default '')
returns table(review_id uuid, reviewed_order_count bigint, reviewed_amount_iqd numeric)
language plpgsql security definer set search_path = '' as $$
declare v_count bigint; v_amount numeric; v_blocked bigint; v_missing bigint; v_id uuid; v_fingerprint text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_edit'),false)
 then raise exception 'Not authorized'; end if;
 if p_guest_session_id is null then raise exception 'Guest session required'; end if;
 if length(coalesce(p_note,'')) > 500 then raise exception 'Note too long'; end if;
 perform 1 from public.gs_motel_guest_stay_sessions where id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 select count(*) into v_missing
 from public.gs_motel_guest_food_requests o
 where o.guest_session_id=p_guest_session_id and o.status='delivered'
 and not exists(select 1 from public.gs_motel_food_billing_ledger l where l.request_id=o.id);
 if v_missing>0 then raise exception 'Delivered food orders missing from ledger: %',v_missing; end if;
 select count(*),coalesce(sum(l.amount_iqd),0),
 count(*) filter (where o.status <> 'delivered' or o.delivered_at is null
  or o.total_iqd <> l.amount_iqd or l.payment_status <> 'unpaid' or l.invoice_id is not null
  or o.guest_session_id <> l.guest_session_id or o.room_id <> l.room_id
  or (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
      where i.request_id=o.id) <> l.amount_iqd)
 into v_count,v_amount,v_blocked
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id;
 if v_count=0 or v_blocked>0 then raise exception 'Food draft has no eligible orders or requires reconciliation'; end if;
 select (select md5(coalesce(string_agg(
  l.request_id::text || ':' || l.room_id::text || ':' || l.amount_iqd::text || ':' ||
  o.status || ':' || coalesce(o.delivered_at::text,'') || ':' ||
  coalesce((select string_agg(i.id::text || '=' || i.line_total_iqd::text, ',' order by i.id)
    from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'')
 , '|' order by l.request_id),''))
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id) into v_fingerprint;
 insert into public.gs_motel_food_draft_reviews(guest_session_id,reviewed_by,order_count,amount_iqd,note,order_fingerprint)
 values(p_guest_session_id,auth.uid(),v_count,v_amount,coalesce(p_note,''),v_fingerprint)
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
 return query
 select r.guest_session_id,r.reviewed_at,r.reviewed_by,r.order_count,r.amount_iqd,
 (select count(*) from public.gs_motel_food_billing_ledger l where l.guest_session_id=r.guest_session_id)::bigint,
 (select coalesce(sum(l.amount_iqd),0) from public.gs_motel_food_billing_ledger l where l.guest_session_id=r.guest_session_id)::numeric,
 (r.order_fingerprint is distinct from (select md5(coalesce(string_agg(
  l.request_id::text || ':' || l.room_id::text || ':' || l.amount_iqd::text || ':' ||
  o.status || ':' || coalesce(o.delivered_at::text,'') || ':' ||
  coalesce((select string_agg(i.id::text || '=' || i.line_total_iqd::text, ',' order by i.id)
    from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'')
 , '|' order by l.request_id),''))
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=r.guest_session_id)
 or r.order_count<>(select count(*) from public.gs_motel_food_billing_ledger l where l.guest_session_id=r.guest_session_id)
 or r.amount_iqd<>(select coalesce(sum(l.amount_iqd),0) from public.gs_motel_food_billing_ledger l where l.guest_session_id=r.guest_session_id)
 or exists(select 1 from public.gs_motel_guest_food_requests o
           where o.guest_session_id=r.guest_session_id and o.status='delivered'
           and not exists(select 1 from public.gs_motel_food_billing_ledger l where l.request_id=o.id))
 or exists(select 1 from public.gs_motel_food_billing_ledger l
           join public.gs_motel_guest_food_requests o on o.id=l.request_id
           where l.guest_session_id=r.guest_session_id
           and (o.status<>'delivered' or o.delivered_at is null or o.total_iqd<>l.amount_iqd
           or l.payment_status<>'unpaid' or l.invoice_id is not null
           or o.guest_session_id<>l.guest_session_id or o.room_id<>l.room_id
           or (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
               where i.request_id=o.id)<>l.amount_iqd)))
 from public.gs_motel_food_draft_reviews r
 order by r.reviewed_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_motel_food_draft_review_status() from public;
grant execute on function public.gs_staff_motel_food_draft_review_status() to authenticated;
create or replace function public.gs_staff_rereview_motel_food_draft(p_guest_session_id uuid,p_reason text)
returns table(review_id uuid,reviewed_order_count bigint,reviewed_amount_iqd numeric)
language plpgsql security definer set search_path = '' as $$
declare v_previous public.gs_motel_food_draft_reviews%rowtype;
 v_count bigint; v_amount numeric; v_bad bigint; v_missing bigint; v_fingerprint text;
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
 select (select md5(coalesce(string_agg(
  l.request_id::text || ':' || l.room_id::text || ':' || l.amount_iqd::text || ':' ||
  o.status || ':' || coalesce(o.delivered_at::text,'') || ':' ||
  coalesce((select string_agg(i.id::text || '=' || i.line_total_iqd::text, ',' order by i.id)
    from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'')
 , '|' order by l.request_id),''))
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id) into v_fingerprint;
 if v_previous.order_fingerprint is not distinct from v_fingerprint and v_previous.order_count=v_count and v_previous.amount_iqd=v_amount then
  raise exception 'Existing review is current; no re-review needed'; end if;
 insert into public.gs_motel_food_draft_review_history(
 guest_session_id,previous_reviewed_by,previous_reviewed_at,previous_order_count,
 previous_amount_iqd,previous_order_fingerprint,replaced_by,reason)
 values(p_guest_session_id,v_previous.reviewed_by,v_previous.reviewed_at,
 v_previous.order_count,v_previous.amount_iqd,v_previous.order_fingerprint,auth.uid(),trim(p_reason));
 update public.gs_motel_food_draft_reviews set reviewed_by=auth.uid(),reviewed_at=now(),
 order_count=v_count,amount_iqd=v_amount,order_fingerprint=v_fingerprint,note=trim(p_reason)
 where id=v_previous.id;
 return query select v_previous.id,v_count,v_amount;
end; $$;
revoke all on function public.gs_staff_rereview_motel_food_draft(uuid,text) from public;
grant execute on function public.gs_staff_rereview_motel_food_draft(uuid,text) to authenticated;
