-- Upgrade 1175: acceptance requires a preparation estimate.
-- Existing status RPC remains for preparing->ready->served; a trigger blocks
-- legacy new->preparing calls without an estimate.
alter table public.gs_orders
  add column if not exists kitchen_accepted_at timestamptz,
  add column if not exists kitchen_accepted_by uuid references auth.users(id),
  add column if not exists kitchen_estimated_minutes integer,
  add column if not exists kitchen_estimated_ready_at timestamptz;
alter table public.gs_orders
  drop constraint if exists gs_kitchen_eta_range;
alter table public.gs_orders
  add constraint gs_kitchen_eta_range
  check (kitchen_estimated_minutes is null or kitchen_estimated_minutes between 1 and 480);

create or replace function public.gs_require_kitchen_acceptance_eta()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'new' and new.status = 'preparing'
     and (new.kitchen_accepted_at is null
          or new.kitchen_accepted_by is null
          or new.kitchen_estimated_minutes is null
          or new.kitchen_estimated_minutes not between 1 and 480
          or new.kitchen_estimated_ready_at is null) then
    raise exception 'Preparation estimate is required before accepting an order';
  end if;
  return new;
end;
$$;
drop trigger if exists gs_require_kitchen_acceptance_eta on public.gs_orders;
create trigger gs_require_kitchen_acceptance_eta
before update of status on public.gs_orders
for each row execute function public.gs_require_kitchen_acceptance_eta();
revoke all on function public.gs_require_kitchen_acceptance_eta() from public, anon, authenticated;

create or replace function public.gs_accept_kitchen_order(
  p_order_id bigint, p_estimated_minutes integer
) returns void language plpgsql security definer set search_path = '' as $$
declare v_current text;
begin
  if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
    raise exception 'Not authorized to accept kitchen orders';
  end if;
  if p_order_id is null or p_order_id <= 0
     or p_estimated_minutes is null or p_estimated_minutes not between 1 and 480 then
    raise exception 'Valid order and estimated minutes (1-480) required';
  end if;
  select status into v_current from public.gs_orders
   where id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if v_current <> 'new' then raise exception 'Order is no longer new'; end if;
  update public.gs_orders
    set kitchen_accepted_at = transaction_timestamp(),
        kitchen_accepted_by = auth.uid(),
        kitchen_estimated_minutes = p_estimated_minutes,
        kitchen_estimated_ready_at = transaction_timestamp() +
          make_interval(mins => p_estimated_minutes)
    where id = p_order_id;
  -- Reuse the existing authorized transition RPC and its validation.
  perform public.gs_update_kitchen_status(p_order_id, 'preparing');
end;
$$;
revoke all on function public.gs_accept_kitchen_order(bigint,integer) from public, anon;
grant execute on function public.gs_accept_kitchen_order(bigint,integer) to authenticated;
