-- Upgrade 384: read-only listing of posted motel-food finance invoices.
create or replace function public.gs_staff_list_motel_food_finance_invoices()
returns table(finance_invoice_id uuid,food_invoice_id uuid,guest_session_id uuid,room_id uuid,source_count integer,total_iqd bigint,payment_status text,posted_at timestamptz,posted_by uuid)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and finance viewing permissions required';
 end if;
 return query select f.id,f.food_invoice_id,f.guest_session_id,f.room_id,f.source_count,f.total_iqd,f.payment_status,f.posted_at,f.posted_by
 from public.gs_motel_food_finance_invoices f order by f.posted_at desc limit 200;
end; $$;
revoke all on function public.gs_staff_list_motel_food_finance_invoices() from public,anon;
grant execute on function public.gs_staff_list_motel_food_finance_invoices() to authenticated;
