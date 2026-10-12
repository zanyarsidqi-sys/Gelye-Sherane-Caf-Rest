-- Upgrade 186: serialized fulfillment transitions with audit/notification outbox.
create table if not exists public.gs_table_item_fulfillment_events (
 id bigint generated always as identity primary key,
 order_item_id bigint not null references public.gs_order_items(id),
 from_status text not null, to_status text not null,
 actor uuid not null references auth.users(id),
 occurred_at timestamptz not null default now()
);
create index if not exists gs_item_fulfillment_events_item
 on public.gs_table_item_fulfillment_events(order_item_id,occurred_at);
alter table public.gs_table_item_fulfillment_events enable row level security;
revoke all on public.gs_table_item_fulfillment_events from public,anon,authenticated;

create or replace function public.gs_advance_table_item_fulfillment(
 p_order_item_id bigint,p_expected_status text,p_next_status text)
returns text language plpgsql volatile security definer set search_path='' as $$
declare v_old text; v_order bigint; v_status text;
begin
 if auth.uid() is null or not (
   public.gs_can_access('table_orders','can_edit') or
   public.gs_can_access('kitchen','can_edit') or
   public.gs_can_access('tables','can_edit')) then
  raise exception 'Not authorized to update fulfillment';
 end if;
 -- Lock parent item to serialize first transitions where fulfillment row is absent.
 select i.order_id into v_order from public.gs_order_items i
 where i.id=p_order_item_id for update;
 if not found then raise exception 'Order item not found'; end if;
 select o.status into v_status from public.gs_orders o where o.id=v_order;
 if v_status is null or v_status in ('cancelled','draft') then
  raise exception 'Order is not eligible for fulfillment';
 end if;
 insert into public.gs_table_item_fulfillment(order_item_id,status)
 values(p_order_item_id,'not_accepted') on conflict(order_item_id) do nothing;
 select f.status into v_old from public.gs_table_item_fulfillment f
 where f.order_item_id=p_order_item_id for update;
 if v_old is distinct from p_expected_status then
  raise exception 'Status changed; refresh item'; end if;
 if not ((v_old='not_accepted' and p_next_status='accepted') or
  (v_old='accepted' and p_next_status='preparing') or
  (v_old='preparing' and p_next_status='prepared') or
  (v_old='prepared' and p_next_status='picked_up') or
  (v_old='picked_up' and p_next_status='delivered')) then
  raise exception 'Invalid fulfillment transition'; end if;
 update public.gs_table_item_fulfillment set status=p_next_status,
  accepted_by=case when p_next_status='accepted' then auth.uid() else accepted_by end,
  prepared_by=case when p_next_status='prepared' then auth.uid() else prepared_by end,
  picked_by=case when p_next_status='picked_up' then auth.uid() else picked_by end,
  delivered_by=case when p_next_status='delivered' then auth.uid() else delivered_by end,
  updated_at=now() where order_item_id=p_order_item_id;
 insert into public.gs_table_item_fulfillment_events(
  order_item_id,from_status,to_status,actor)
 values(p_order_item_id,v_old,p_next_status,auth.uid());
 return p_next_status;
end; $$;
revoke all on function public.gs_advance_table_item_fulfillment(bigint,text,text)
 from public,anon;
grant execute on function public.gs_advance_table_item_fulfillment(bigint,text,text)
 to authenticated;
