-- Upgrade 1149: read-only STAGING deployment preflight. All passed must be true.
with checks(name, passed) as (
 select 'status RPC exists', to_regprocedure('public.gs_update_kitchen_status(bigint,text)') is not null
 union all select 'status RPC security definer', coalesce((select prosecdef from pg_proc where oid=to_regprocedure('public.gs_update_kitchen_status(bigint,text)')),false)
 union all select 'status RPC authenticated grant', coalesce(has_function_privilege('authenticated',to_regprocedure('public.gs_update_kitchen_status(bigint,text)'),'EXECUTE'),false)
 union all select 'status RPC anon denied', not coalesce(has_function_privilege('anon',to_regprocedure('public.gs_update_kitchen_status(bigint,text)'),'EXECUTE'),true)
 union all select 'status RPC PUBLIC denied', not exists (select 1 from pg_proc p, lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where p.oid=to_regprocedure('public.gs_update_kitchen_status(bigint,text)') and a.grantee=0 and a.privilege_type='EXECUTE')
 union all select 'orders table exists', to_regclass('public.gs_orders') is not null
 union all select 'items table exists', to_regclass('public.gs_order_items') is not null
 union all select 'served guard exists', to_regprocedure('public.gs_guard_served_order_items()') is not null
 union all select 'served guard security definer', coalesce((select prosecdef from pg_proc where oid=to_regprocedure('public.gs_guard_served_order_items()')),false)
 union all select 'served guard anon denied', not coalesce(has_function_privilege('anon',to_regprocedure('public.gs_guard_served_order_items()'),'EXECUTE'),true)
 union all select 'served guard authenticated denied', not coalesce(has_function_privilege('authenticated',to_regprocedure('public.gs_guard_served_order_items()'),'EXECUTE'),true)
 union all select 'served guard trigger enabled for all writes', exists(select 1 from pg_trigger t where t.tgrelid=to_regclass('public.gs_order_items') and t.tgname='gs_guard_served_order_items' and t.tgenabled in ('O','A') and (t.tgtype & 4)<>0 and (t.tgtype & 8)<>0 and (t.tgtype & 16)<>0)
)
select name,passed from checks order by name;
-- Run on staging after migrations. Every passed must be true. Does not test behavior.
