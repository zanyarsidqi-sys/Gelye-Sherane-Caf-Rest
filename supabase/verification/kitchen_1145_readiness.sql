-- Upgrade 1145: non-mutating Kitchen schema readiness report.
-- Run in Supabase SQL Editor AFTER applying migrations 1142, 1143, 1144.
-- This checks database objects and trigger installation, NOT live concurrency.
with checks(check_name, passed, details) as (
  select 'orders table', to_regclass('public.gs_orders') is not null,
         'public.gs_orders must exist'
  union all select 'order items table', to_regclass('public.gs_order_items') is not null,
         'public.gs_order_items must exist'
  union all select 'kitchen status RPC', to_regprocedure('public.gs_update_kitchen_status(bigint,text)') is not null,
         'RPC must be deployed'
  union all select 'served item guard function', to_regprocedure('public.gs_guard_served_order_items()') is not null,
         'guard function must be deployed'
  union all select 'served item guard trigger', exists (
      select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='gs_order_items'
      and t.tgname='gs_guard_served_order_items' and t.tgenabled <> 'D'
      and not t.tgisinternal), 'trigger must be enabled'
  union all select 'RPC execute for authenticated',
      coalesce(has_function_privilege('authenticated',
        to_regprocedure('public.gs_update_kitchen_status(bigint,text)'), 'EXECUTE'),false),
      'authenticated role must be able to invoke RPC'
  union all select 'RPC not executable by anon',
      not coalesce(has_function_privilege('anon',
        to_regprocedure('public.gs_update_kitchen_status(bigint,text)'), 'EXECUTE'),true),
      'anonymous role must not execute RPC'
  union all select 'guard not executable by authenticated',
      not coalesce(has_function_privilege('authenticated',
        to_regprocedure('public.gs_guard_served_order_items()'), 'EXECUTE'),true),
      'trigger function must not be directly executable'
)
select check_name, passed, details from checks order by check_name;
-- Expected: all 8 rows passed=true. Also test real order transactions,
-- simultaneous serve/edit, and cross-section UI on a staging environment.
