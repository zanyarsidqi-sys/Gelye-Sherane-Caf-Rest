-- Upgrade 242: Conservative, read-only payment source reconciliation.
-- This function does NOT settle bills, alter totals, or authorize discounts.
create or replace function public.gs_admin_discount_payment_reconciliation(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_total bigint;
 v_status text;
 v_relation text;
 v_sources jsonb := '[]'::jsonb;
 v_unresolved jsonb := '[]'::jsonb;
 v_found boolean;
 v_column_count integer;
 v_eligible boolean := true;
begin
 if auth.uid() is null or not exists (
   select 1 from public.gs_cafe_discount_admins where user_id = auth.uid()
 ) then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order'; end if;
 select status::text into v_status from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Order not found'; end if;
 select coalesce(sum(line_total_iqd),0)::bigint into v_total
 from public.gs_order_items where order_id=p_order_id;
 if v_total <= 0 or v_status in ('cancelled','paid','settled','closed','completed')
 then v_eligible := false; end if;
 -- A payment source with an unknown schema is an unresolved blocker, not evidence of zero payments.
 foreach v_relation in array array[
   'gs_cash_payments','gs_cash_only_settlement_attestations',
   'gs_unified_payment_ledger','gs_payment_ledger','gs_credit_transactions',
   'gs_mixed_payment_finance_attestations','gs_item_payment_allocations',
   'gs_order_payment_confirmations'
 ] loop
   if to_regclass('public.' || v_relation) is not null then
     select count(*) into v_column_count from information_schema.columns
     where table_schema='public' and table_name=v_relation and column_name='order_id';
     if v_column_count=0 then
       v_unresolved := v_unresolved || jsonb_build_array(v_relation || ': no order_id column');
       v_eligible := false;
     else
       execute format('select exists(select 1 from public.%I where order_id=$1)',v_relation)
         into v_found using p_order_id;
       if v_found then
         v_sources := v_sources || jsonb_build_array(v_relation);
         v_eligible := false;
       end if;
     end if;
   end if;
 end loop;
 -- This is a diagnostic only; other payment systems may exist outside this inventory.
 return jsonb_build_object('order_id',p_order_id,'order_status',v_status,
   'order_total_iqd',v_total,'payment_sources',v_sources,
   'unresolved_sources',v_unresolved,
   'eligibility',case when v_eligible then 'provisional_no_known_payment' else 'blocked' end,
   'final_settlement_authorized',false,'read_only',true);
end; $$;
revoke all on function public.gs_admin_discount_payment_reconciliation(bigint) from public,anon;
grant execute on function public.gs_admin_discount_payment_reconciliation(bigint) to authenticated;
