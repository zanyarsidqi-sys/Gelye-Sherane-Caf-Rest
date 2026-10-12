-- DRAFT: read-only owner-guest complimentary approval ledger.
-- Do NOT use this table to reduce a bill until server-side owner verification,
-- eligible item linkage and payment ledger posting are implemented.
create table if not exists public.gs_owner_guest_offers (
 id bigint generated always as identity primary key,
 table_reference text not null,
 requested_by uuid not null references auth.users(id),
 owner_approved_by uuid references auth.users(id),
 status text not null default 'pending'
   check(status in ('pending','verified','rejected','cancelled')),
 complimentary_amount_iqd bigint not null default 0
   check(complimentary_amount_iqd>=0),
 verified_at timestamptz,
 created_at timestamptz not null default now(),
 constraint gs_owner_offer_verified_consistency check (
  (status='verified' and owner_approved_by is not null and verified_at is not null)
  or (status<>'verified' and owner_approved_by is null and verified_at is null)
 )
);
alter table public.gs_owner_guest_offers enable row level security;
revoke all on public.gs_owner_guest_offers from anon,authenticated;

create or replace function public.gs_dashboard_owner_guest_offers()
returns table (id bigint, table_reference text, status text,
 complimentary_amount_iqd bigint, verified_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('dashboard','can_view')
   or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Owner offer access denied';
 end if;
 return query select o.id,o.table_reference,o.status,
   o.complimentary_amount_iqd,o.verified_at
 from public.gs_owner_guest_offers o order by o.created_at desc limit 200;
end; $$;
revoke all on function public.gs_dashboard_owner_guest_offers() from public,anon;
grant execute on function public.gs_dashboard_owner_guest_offers() to authenticated;
-- No write RPC: staff cannot claim owner verification. Future approval must
-- require actual owner role, step-up auth, item/bill linkage, and audit.
