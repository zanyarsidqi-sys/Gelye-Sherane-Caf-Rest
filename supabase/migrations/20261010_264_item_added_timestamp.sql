-- Upgrade 264: capture server-authoritative insertion time for each order item.
-- Existing rows have no historical per-item insertion timestamp. Their backfill
-- uses the parent order timestamp and must be identified as approximate.
alter table public.gs_order_items add column if not exists added_at timestamptz;
update public.gs_order_items i set added_at = o.created_at
from public.gs_orders o where o.id=i.order_id and i.added_at is null;
alter table public.gs_order_items alter column added_at set default now();
alter table public.gs_order_items alter column added_at set not null;
comment on column public.gs_order_items.added_at is
 'Server-side item insertion time. Existing items were backfilled from order creation and may be approximate.';

create or replace function public.gs_protect_item_added_at()
returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op='UPDATE' and new.added_at is distinct from old.added_at then
   raise exception 'Original item-added timestamp is immutable';
 end if;
 return new;
end $$;
drop trigger if exists gs_protect_item_added_at_trg on public.gs_order_items;
create trigger gs_protect_item_added_at_trg before update on public.gs_order_items
for each row execute function public.gs_protect_item_added_at();

-- Timeline now uses each item's timestamp rather than its parent order timestamp.
create or replace function public.gs_staff_table_item_timeline(p_order_item_id bigint)
returns table(event_kind text, event_label text, occurred_at timestamptz,
  actor_id uuid, previous_value text, new_value text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('table_orders','can_view') or
  public.gs_can_access('kitchen','can_view') or
  public.gs_can_access('tables','can_view')) then
  raise exception 'Not authorized to view item timeline';
 end if;
 if not exists (
  select 1 from public.gs_order_items i
  join public.gs_orders o on o.id=i.order_id
  join public.gs_table_visits v on v.id=o.table_visit_id
  where i.id=p_order_item_id and o.is_motel=false and v.status='open'
 ) then raise exception 'Item not found in an open table visit'; end if;
 return query
 select e.event_kind,e.event_label,e.occurred_at,e.actor_id,
        e.previous_value,e.new_value from (
  select 'ordered'::text event_kind,'Item added to order'::text event_label,
    coalesce(i.added_at, o.created_at) occurred_at,null::uuid actor_id,null::text previous_value,
    null::text new_value,0::bigint event_id
  from public.gs_order_items i join public.gs_orders o on o.id=i.order_id
  where i.id=p_order_item_id
  union all
  select 'fulfillment'::text, f.to_status::text, f.occurred_at,
    f.actor, f.from_status::text,f.to_status::text,f.id
  from public.gs_table_item_fulfillment_events f
  where f.order_item_id=p_order_item_id
  union all
  select 'instruction_change'::text,'Instructions changed'::text,
    a.changed_at,a.actor,a.previous_instructions,a.new_instructions,a.id
  from public.gs_order_item_instruction_edit_audit a
  where a.order_item_id=p_order_item_id
 ) e order by e.occurred_at asc,e.event_id asc;
end $$;
revoke all on function public.gs_staff_table_item_timeline(bigint) from public,anon;
grant execute on function public.gs_staff_table_item_timeline(bigint) to authenticated;
