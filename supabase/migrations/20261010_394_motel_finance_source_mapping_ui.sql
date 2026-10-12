-- Upgrade 394: read-only source bridge inspection for finance employees.
-- Source creation remains exclusively in the validated Upgrade 393 RPC.
create or replace function public.gs_staff_get_motel_finance_source(p_invoice_id uuid)
returns table(bridge_id uuid, guest_session_id uuid, room_id uuid,
 amount_iqd bigint, mapping_status text, legacy_order_id bigint, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 if not exists(select 1 from public.gs_motel_food_finance_invoices f where f.id=p_invoice_id) then
  raise exception 'Finance invoice not found';
 end if;
 return query select b.id,b.guest_session_id,b.room_id,b.amount_iqd,
  b.mapping_status,b.legacy_order_id,b.created_at
 from public.gs_motel_finance_source_bridge b
 where b.finance_invoice_id=p_invoice_id;
end; $$;
revoke all on function public.gs_staff_get_motel_finance_source(uuid) from public,anon;
grant execute on function public.gs_staff_get_motel_finance_source(uuid) to authenticated;
