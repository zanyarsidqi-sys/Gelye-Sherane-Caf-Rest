-- Upgrade 369: read-only, fingerprint-verified handoff manifest for invoice integration.
-- Does not create official invoices, change ledger records, or post payments.
create or replace function public.gs_staff_motel_food_invoice_handoff_manifest(p_guest_session_id uuid)
returns table(request_id uuid, room_id uuid, amount_iqd bigint, review_id uuid,
                reviewed_at timestamptz, review_fingerprint text)
language plpgsql security definer set search_path = '' as $$
declare v_review public.gs_motel_food_draft_reviews%rowtype;
 v_fingerprint text; v_count bigint; v_total numeric; v_invalid bigint; v_missing bigint;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 if p_guest_session_id is null then raise exception 'Guest stay required'; end if;
 -- Lock the stay for consistency with the existing review/re-review workflows.
 perform 1 from public.gs_motel_guest_stay_sessions s where s.id=p_guest_session_id for update;
 if not found then raise exception 'Guest stay not found'; end if;
 select * into v_review from public.gs_motel_food_draft_reviews r
 where r.guest_session_id=p_guest_session_id;
 if not found or v_review.order_fingerprint is null then
  raise exception 'Current fingerprinted employee review required'; end if;
 select count(*) into v_missing from public.gs_motel_guest_food_requests o
 where o.guest_session_id=p_guest_session_id and o.status='delivered'
 and not exists(select 1 from public.gs_motel_food_billing_ledger l where l.request_id=o.id);
 select count(*),coalesce(sum(l.amount_iqd),0),
 count(*) filter(where o.status<>'delivered' or o.delivered_at is null
  or o.total_iqd<>l.amount_iqd or l.payment_status<>'unpaid' or l.invoice_id is not null
  or o.guest_session_id<>l.guest_session_id or o.room_id<>l.room_id
  or (select coalesce(sum(i.line_total_iqd),0) from public.gs_motel_guest_food_request_items i
       where i.request_id=o.id)<>l.amount_iqd)
 into v_count,v_total,v_invalid
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id;
 if v_missing>0 or v_invalid>0 or v_count=0 then
  raise exception 'Invoice handoff blocked: food ledger reconciliation required'; end if;
 select md5(coalesce(string_agg(
  l.request_id::text || ':' || l.room_id::text || ':' || l.amount_iqd::text || ':' ||
  o.status || ':' || coalesce(o.delivered_at::text,'') || ':' ||
  coalesce((select string_agg(i.id::text || '=' || i.line_total_iqd::text, ',' order by i.id)
    from public.gs_motel_guest_food_request_items i where i.request_id=o.id),'')
 , '|' order by l.request_id),'')) into v_fingerprint
 from public.gs_motel_food_billing_ledger l
 join public.gs_motel_guest_food_requests o on o.id=l.request_id
 where l.guest_session_id=p_guest_session_id;
 if v_review.order_fingerprint is distinct from v_fingerprint
    or v_review.order_count<>v_count or v_review.amount_iqd<>v_total then
  raise exception 'Invoice handoff blocked: employee review is outdated'; end if;
 return query select l.request_id,l.room_id,l.amount_iqd,v_review.id,v_review.reviewed_at,v_fingerprint
 from public.gs_motel_food_billing_ledger l
 where l.guest_session_id=p_guest_session_id order by l.request_id;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_handoff_manifest(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_invoice_handoff_manifest(uuid) to authenticated;
