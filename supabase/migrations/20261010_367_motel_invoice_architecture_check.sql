-- Upgrade 367: invoice integration architecture and review fingerprint diagnostic.
-- This remains read-only and does not bypass the staging ledger's invoice_id IS NULL guard.
-- A reviewed count + total is not enough to prove that the same orders remain in the draft.
create or replace function public.gs_staff_motel_food_invoice_architecture_check()
returns table(check_name text, check_status text, details text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 then raise exception 'Not authorized'; end if;
 return query
 select 'staging_invoice_link'::text,'blocked'::text,
        'gs_motel_food_billing_ledger enforces invoice_id IS NULL; no official invoice posting is enabled'::text
 union all
 select 'guest_stay_scoping'::text,'required'::text,
        'Official invoice integration must bind every line to the original guest session and room'::text
 union all
 select 'payment_allocation'::text,'not_connected'::text,
        'Cash, credit and electronic payment allocations are not connected to motel food drafts'::text
 union all
 select 'review_identity'::text,'needs_hardening'::text,
        'Current review status compares count and amount only; unchanged totals do not guarantee unchanged order identities'::text;
end; $$;
revoke all on function public.gs_staff_motel_food_invoice_architecture_check() from public;
grant execute on function public.gs_staff_motel_food_invoice_architecture_check() to authenticated;
