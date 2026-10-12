-- Upgrade 1147: read-only STAGING deployment verification, after migrations 1142-1144.
-- All rows must show passed = true; this script does not apply migrations.
with checks(check_name, passed, details) as (
 select 'status RPC exists', to_regprocedure('public.gs_update_kitchen_status(bigint,text)') is not null, 'Status RPC must be deployed'
 union all select 'authenticated may execute status RPC', coalesce(has_function_privilege('authenticated', to_regprocedure('public.gs_update_kitchen_status(bigint,text)'), 'EXECUTE'), false), 'Only authorized employee requests may use the RPC'
 union all select 'anon may not execute status RPC', not coalesce(has_function_privilege('anon', to_regprocedure('public.gs_update_kitchen_status(bigint,text)'), 'EXECUTE'), true), 'Anonymous role must not execute'
 union all select 'PUBLIC may not execute status RPC', not exists (
   select 1 from pg_proc p where p.oid = to_regprocedure('public.gs_update_kitchen_status(bigint,text)')
   and exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
 ), 'PUBLIC execute must be revoked'
 union all select 'guard exists', to_regprocedure('public.gs_guard_served_order_items()') is not null, 'Trigger function must be deployed'
 union all select 'anon may not execute guard', not coalesce(has_function_privilege('anon', to_regprocedure('public.gs_guard_served_order_items()'), 'EXECUTE'), true), 'Trigger helper not callable by anon'
 union all select 'authenticated may not execute guard', not coalesce(has_function_privilege('authenticated', to_regprocedure('public.gs_guard_served_order_items()'), 'EXECUTE'), true), 'Trigger helper not callable by authenticated'
 union all select 'served item trigger enabled', exists (
  select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname='gs_order_items' and t.tgname='gs_guard_served_order_items'
  and not t.tgisinternal and t.tgenabled in ('O','A')
 ), 'Guard trigger must be active'
)
select check_name, passed, details from checks order by check_name;
