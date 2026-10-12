-- Upgrade 204: private customer directory and audited manual visit log.
-- Spend is deliberately not inferred from unverified table/payment records.
create table if not exists public.gs_cafe_customer_profiles (
 id bigint generated always as identity primary key,
 full_name text not null check (length(trim(full_name)) between 2 and 120),
 phone text check (phone is null or length(phone) between 6 and 30),
 notes text check (notes is null or length(notes)<=1000),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id)
);
create table if not exists public.gs_cafe_customer_visits (
 id bigint generated always as identity primary key,
 customer_id bigint not null references public.gs_cafe_customer_profiles(id) on delete restrict,
 table_number integer,
 visited_at timestamptz not null default now(),
 notes text check (notes is null or length(notes)<=500),
 created_by uuid not null references auth.users(id)
);
create index if not exists gs_cafe_customer_visits_customer_idx on public.gs_cafe_customer_visits(customer_id,visited_at desc);
alter table public.gs_cafe_customer_profiles enable row level security;
alter table public.gs_cafe_customer_visits enable row level security;
revoke all on public.gs_cafe_customer_profiles,public.gs_cafe_customer_visits from public,anon,authenticated;
create or replace function public.gs_add_cafe_customer(p_name text,p_phone text default null,p_notes text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not (public.gs_can_access('customers','can_edit') or public.gs_can_access('tables','can_edit')) then
  raise exception 'Customer edit permission required'; end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 120 or length(coalesce(p_notes,''))>1000 or
    (nullif(trim(coalesce(p_phone,'')),'') is not null and length(trim(p_phone)) not between 6 and 30) then
  raise exception 'Invalid customer details'; end if;
 insert into public.gs_cafe_customer_profiles(full_name,phone,notes,created_by)
 values(trim(p_name),nullif(trim(coalesce(p_phone,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_id;
 return v_id;
end $$;
create or replace function public.gs_record_cafe_customer_visit(p_customer_id bigint,p_table_number integer default null,p_notes text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
 if auth.uid() is null or not (public.gs_can_access('customers','can_edit') or public.gs_can_access('tables','can_edit')) then
  raise exception 'Customer edit permission required'; end if;
 if not exists(select 1 from public.gs_cafe_customer_profiles where id=p_customer_id) then raise exception 'Customer not found'; end if;
 if p_table_number is not null and not exists(select 1 from public.gs_cafe_tables where table_number=p_table_number) then
  raise exception 'Table not found'; end if;
 if length(coalesce(p_notes,''))>500 then raise exception 'Notes too long'; end if;
 insert into public.gs_cafe_customer_visits(customer_id,table_number,notes,created_by)
 values(p_customer_id,p_table_number,nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_id;
 return v_id;
end $$;
create or replace function public.gs_list_cafe_customers()
returns table(id bigint,full_name text,phone text,notes text,visit_count bigint,last_visit timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('customers','can_view') or public.gs_can_access('tables','can_view')) then
  raise exception 'Customer view permission required'; end if;
 return query select c.id,c.full_name,c.phone,c.notes,count(v.id)::bigint,max(v.visited_at)
 from public.gs_cafe_customer_profiles c left join public.gs_cafe_customer_visits v on v.customer_id=c.id
 group by c.id,c.full_name,c.phone,c.notes order by count(v.id) desc,c.full_name limit 2000;
end $$;
create or replace function public.gs_cafe_customer_visit_history(p_customer_id bigint)
returns table(id bigint,table_number integer,visited_at timestamptz,notes text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('customers','can_view') or public.gs_can_access('tables','can_view')) then
  raise exception 'Customer view permission required'; end if;
 return query select v.id,v.table_number,v.visited_at,v.notes from public.gs_cafe_customer_visits v
 where v.customer_id=p_customer_id order by v.visited_at desc limit 500;
end $$;
revoke all on function public.gs_add_cafe_customer(text,text,text),public.gs_record_cafe_customer_visit(bigint,integer,text),public.gs_list_cafe_customers(),public.gs_cafe_customer_visit_history(bigint) from public,anon;
grant execute on function public.gs_add_cafe_customer(text,text,text),public.gs_record_cafe_customer_visit(bigint,integer,text),public.gs_list_cafe_customers(),public.gs_cafe_customer_visit_history(bigint) to authenticated;
