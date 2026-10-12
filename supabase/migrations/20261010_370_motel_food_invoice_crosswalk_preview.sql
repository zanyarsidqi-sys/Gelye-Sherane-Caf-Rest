-- Upgrade 370: stable food-order invoice crosswalk preview, NO financial posting.
-- A future official invoice writer must consume a verified manifest transactionally.
create or replace function public.gs_staff_motel_food_invoice_crosswalk_preview(p_guest_session_id uuid)
returns table(source_type text, source_order_id uuid, source_ledger_id uuid,
 guest_session_id uuid, room_id uuid, amount_iqd bigint, source_key text,
 review_id uuid, review_fingerprint text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 -- Reuse the existing review, line-total, stay, and fingerprint verification.
 return query
 select 'motel_food_order'::text, m.request_id, l.id, p_guest_session_id,
        m.room_id, m.amount_iqd,
        'motel_food_order:' || m.request_id::text,
        m.review_id, m.review_fingerprint
 from public.gs_staff_motel_food_invoice_handoff_manifest(p_guest_session_id) m
 join public.gs_motel_food_billing_ledger l on l.request_id=m.request_id
  and l.guest_session_id=p_guest_session_id and l.room_id=m.room_id
  and l.amount_iqd=m.amount_iqd
 order by m.request_id;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_crosswalk_preview(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_invoice_crosswalk_preview(uuid) to authenticated;
