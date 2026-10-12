-- Upgrade 413: auditable pending customer/account provisioning and barcode linking.
-- Does not verify ownership, set credit limits, post journal entries or settle invoices.
create table if not exists public.gs_credit_registration_audit (
 id uuid primary key default extensions.gen_random_uuid(),
 action text not null check(action in ('register_account','link_barcode')),
 customer_id uuid references public.gs_credit_customers(id),
 account_id uuid not null references public.gs_credit_accounts(id),
 registry_id uuid references public.gs_motel_credit_barcode_registry(id),
 actor_id uuid not null references auth.users(id),
 recorded_at timestamptz not null default now()
);
alter table public.gs_credit_registration_audit enable row level security;
revoke all on public.gs_credit_registration_audit from public,anon,authenticated;

create or replace function public.gs_staff_register_credit_account(
 p_customer_reference text,p_display_name text,p_account_reference text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_customer uuid; v_account uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_customer_reference is null or length(btrim(p_customer_reference)) not between 3 and 100
 or p_display_name is null or length(btrim(p_display_name)) not between 1 and 120
 or p_account_reference is null or length(btrim(p_account_reference)) not between 3 and 100
 then raise exception 'Invalid customer or account fields'; end if;
 insert into public.gs_credit_customers(customer_reference,display_name,created_by)
 values(btrim(p_customer_reference),btrim(p_display_name),auth.uid())
 on conflict(customer_reference) do nothing returning id into v_customer;
 if v_customer is null then
  select id into v_customer from public.gs_credit_customers
   where customer_reference=btrim(p_customer_reference);
  if v_customer is null then raise exception 'Customer registration conflict, retry'; end if;
 end if;
 insert into public.gs_credit_accounts(customer_id,account_reference)
 values(v_customer,btrim(p_account_reference)) returning id into v_account;
 insert into public.gs_credit_registration_audit(action,customer_id,account_id,actor_id)
 values('register_account',v_customer,v_account,auth.uid());
 return v_account;
end $$;
revoke all on function public.gs_staff_register_credit_account(text,text,text) from public,anon;
grant execute on function public.gs_staff_register_credit_account(text,text,text) to authenticated;

create or replace function public.gs_staff_link_credit_barcode_pending(
 p_registry_id uuid,p_account_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_reference text; v_account_reference text;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 select account_reference into v_reference from public.gs_motel_credit_barcode_registry
 where id=p_registry_id for update;
 if not found then raise exception 'Barcode registry entry not found'; end if;
 select account_reference into v_account_reference from public.gs_credit_accounts
 where id=p_account_id and account_status='pending' for update;
 if not found then raise exception 'Only pending credit accounts may be linked'; end if;
 if v_reference<>v_account_reference then
  raise exception 'Barcode and credit account references must match'; end if;
 insert into public.gs_credit_account_registry_links(registry_id,account_id,linked_by)
 values(p_registry_id,p_account_id,auth.uid());
 insert into public.gs_credit_registration_audit(action,account_id,registry_id,actor_id)
 values('link_barcode',p_account_id,p_registry_id,auth.uid());
 return p_registry_id;
end $$;
revoke all on function public.gs_staff_link_credit_barcode_pending(uuid,uuid) from public,anon;
grant execute on function public.gs_staff_link_credit_barcode_pending(uuid,uuid) to authenticated;
