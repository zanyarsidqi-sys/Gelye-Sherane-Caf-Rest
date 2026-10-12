-- READ ONLY: inspect existing credit/payment infrastructure before any migration.
-- Run in Supabase SQL Editor and share results before backend implementation.
select table_name from information_schema.tables
where table_schema='public' and (table_name ilike '%credit%' or table_name ilike '%payment%' or table_name ilike '%customer%' or table_name in ('gs_orders','gs_order_items'))
order by table_name;

select table_name,column_name,data_type,is_nullable
from information_schema.columns
where table_schema='public' and (table_name ilike '%credit%' or table_name ilike '%payment%' or table_name ilike '%customer%')
order by table_name,ordinal_position;

select schemaname,tablename,rowsecurity from pg_tables
where schemaname='public' and (tablename ilike '%credit%' or tablename ilike '%payment%' or tablename ilike '%customer%')
order by tablename;

select routine_name from information_schema.routines
where routine_schema='public' and (routine_name ilike '%credit%' or routine_name ilike '%payment%' or routine_name ilike '%withdraw%')
order by routine_name;
