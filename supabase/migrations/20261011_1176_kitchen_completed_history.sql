-- Upgrade 1176: authoritative completed timestamp, distinct from order creation.
-- Historic served rows remain NULL: never fabricate their completion dates.
alter table public.gs_orders add column if not exists kitchen_completed_at timestamptz;
create index if not exists gs_orders_kitchen_completed_at_idx
  on public.gs_orders (kitchen_completed_at desc, id desc)
  where status = 'served';
create or replace function public.gs_stamp_kitchen_completion()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status is distinct from 'served' and new.status = 'served' then
    new.kitchen_completed_at := transaction_timestamp();
  end if;
  return new;
end;
$$;
drop trigger if exists gs_stamp_kitchen_completion on public.gs_orders;
create trigger gs_stamp_kitchen_completion
before update of status on public.gs_orders
for each row execute function public.gs_stamp_kitchen_completion();
revoke all on function public.gs_stamp_kitchen_completion() from public, anon, authenticated;
