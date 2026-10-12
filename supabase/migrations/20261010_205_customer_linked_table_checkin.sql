-- Upgrade 205: atomic customer-linked walk-in table check-in.
-- Apply after migrations 151 and 204. Existing table occupancy, cleaning,
-- reservation checks remain enforced by gs_open_cafe_table_visit.
-- Does not change reservation check-in or infer payment/spending history.
alter table public.gs_cafe_customer_visits
 add column if not exists table_visit_id bigint references public.gs_table_visits(id) on delete restrict;
create unique index if not exists gs_customer_visit_one_per_table_visit
 on public.gs_cafe_customer_visits(table_visit_id) where table_visit_id is not null;

create or replace function public.gs_open_cafe_table_visit_with_customer(
 p_table_number integer, p_guests integer, p_tourism boolean default false,
 p_customer_id bigint default null, p_new_customer_name text default null,
 p_new_customer_phone text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_visit_id bigint; v_customer_id bigint; v_name text;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table edit permission required';
 end if;
 v_name := nullif(trim(coalesce(p_new_customer_name,'')),'');
 if p_customer_id is not null and (v_name is not null or nullif(trim(coalesce(p_new_customer_phone,'')),'') is not null) then
  raise exception 'Choose an existing customer OR create a new customer';
 end if;
 if p_customer_id is not null then
  select id into v_customer_id from public.gs_cafe_customer_profiles
  where id=p_customer_id;
  if v_customer_id is null then raise exception 'Customer not found'; end if;
 elsif v_name is not null then
  -- Reuse validated customer creation RPC (same transaction).
  v_customer_id := public.gs_add_cafe_customer(v_name,p_new_customer_phone,null);
 elsif nullif(trim(coalesce(p_new_customer_phone,'')),'') is not null then
  raise exception 'New customer name is required when a phone is supplied';
 end if;
 -- Reuse latest reservation-aware table opening RPC; any exception rolls back
 -- new customer creation and visit-history writes as well.
 v_visit_id := public.gs_open_cafe_table_visit(p_table_number,p_guests,p_tourism);
 if v_customer_id is not null then
  insert into public.gs_cafe_customer_visits(
   customer_id,table_number,visited_at,notes,created_by,table_visit_id)
  values(v_customer_id,p_table_number,now(),null,auth.uid(),v_visit_id);
 end if;
 return v_visit_id;
end $$;
revoke all on function public.gs_open_cafe_table_visit_with_customer(integer,integer,boolean,bigint,text,text) from public,anon;
grant execute on function public.gs_open_cafe_table_visit_with_customer(integer,integer,boolean,bigint,text,text) to authenticated;
