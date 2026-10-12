-- Upgrade 410: Credit Management schema discovery (metadata only).
-- This is not a credit provider, ownership check, balance check, or debit.
create or replace function public.gs_staff_motel_credit_schema_inventory()
returns table(object_name text, object_kind text, column_names text,
              row_security_enabled boolean, integration_note text)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null
    or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management administrator permission required'; end if;
 return query
 select c.relname::text,
        case c.relkind when 'r' then 'table'
          when 'p' then 'partitioned table'
          when 'v' then 'view'
          when 'm' then 'materialized view' else 'other' end::text,
        coalesce((
          select string_agg(a.attname::text || ' (' ||
              pg_catalog.format_type(a.atttypid,a.atttypmod) || ')',
              ', ' order by a.attnum)
          from pg_catalog.pg_attribute a
          where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
        ),'')::text,
        c.relrowsecurity,
        'Schema discovery only: does not establish balance accuracy, ownership or debit capability'::text
 from pg_catalog.pg_class c
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public'
   and c.relkind in ('r','p','v','m')
   and (c.relname ilike '%credit%' or c.relname ilike '%customer%'
        or c.relname ilike '%wallet%' or c.relname ilike '%account%')
 order by c.relname
 limit 100;
end $$;
revoke all on function public.gs_staff_motel_credit_schema_inventory() from public,anon;
grant execute on function public.gs_staff_motel_credit_schema_inventory() to authenticated;
