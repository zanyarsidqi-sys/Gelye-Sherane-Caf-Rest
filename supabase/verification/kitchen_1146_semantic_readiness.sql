-- Upgrade 1146: read-only semantic verification of kitchen database safeguards.
-- Run AFTER migrations 1142-1144 in a staging database. No data is modified.
-- Checks actual deployed definitions, not merely existence of objects.
with defs as (
 select pg_get_functiondef(to_regprocedure('public.gs_update_kitchen_status(bigint,text)')) as status_def,
        pg_get_functiondef(to_regprocedure('public.gs_guard_served_order_items()')) as guard_def
), checks(check_name, passed, details) as (
 select 'served transition validates nonempty items',
        coalesce(status_def ilike '%v_item_count = 0%', false),
        'Status RPC must reject empty served orders' from defs
 union all select 'served transition locks item rows',
        coalesce(status_def ilike '%for update%locked_items%', false),
        'Status RPC must lock child item rows before serving' from defs
 union all select 'served transition validates line totals',
        coalesce(status_def ilike '%line_total_iqd::numeric%quantity::numeric * unit_price_iqd::numeric%', false),
        'Status RPC must validate quantity times unit price' from defs
 union all select 'served item guard locks parent order',
        coalesce(guard_def ilike '%from public.gs_orders%for update%', false),
        'Guard must lock parent row before editing an item' from defs
 union all select 'served item guard blocks served modifications',
        coalesce(guard_def ilike '%v_status = ''served''%', false),
        'Guard must reject edits after served' from defs
 union all select 'guard is attached to all three write operations',
        exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid
          join pg_namespace n on n.oid=c.relnamespace
          where n.nspname='public' and c.relname='gs_order_items'
            and t.tgname='gs_guard_served_order_items'
            and (t.tgtype & 1) = 1
            and (t.tgtype & 4) = 4
            and (t.tgtype & 8) = 8
            and (t.tgtype & 16) = 16
            and t.tgenabled <> 'D'),
        'Guard trigger must cover row-level INSERT UPDATE DELETE'
)
select check_name, passed, details from checks order by check_name;
-- These are semantic source checks only; transaction/concurrency testing is still required.
