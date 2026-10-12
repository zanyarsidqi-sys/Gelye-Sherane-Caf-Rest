-- Upgrade 217: quantity-aware, employee-attributed delivery ledger.
-- This is a backend foundation. Do not use the legacy whole-item pickup/delivery
-- endpoint on items with partial delivery records.
create table if not exists public.gs_table_item_delivery_quantities (
 order_item_id bigint primary key references public.gs_order_items(id) on delete restrict,
 picked_quantity integer not null default 0 check (picked_quantity>=0),
 delivered_quantity integer not null default 0 check (delivered_quantity>=0),
 updated_at timestamptz not null default now(),
 constraint gs_delivery_quantity_order check (delivered_quantity<=picked_quantity)
);
create table if not exists public.gs_table_item_delivery_quantity_events (
 id bigint generated always as identity primary key,
 order_item_id bigint not null references public.gs_order_items(id) on delete restrict,
 job_id bigint not null references public.gs_table_service_jobs(id),
 event_type text not null check (event_type in ('picked_up','delivered')),
 quantity integer not null check (quantity>0),
 actor uuid not null references auth.users(id),
 occurred_at timestamptz not null default now()
);
create index if not exists gs_delivery_quantity_events_item
 on public.gs_table_item_delivery_quantity_events(order_item_id,occurred_at);
alter table public.gs_table_item_delivery_quantities enable row level security;
alter table public.gs_table_item_delivery_quantity_events enable row level security;
revoke all on public.gs_table_item_delivery_quantities from public,anon,authenticated;
revoke all on public.gs_table_item_delivery_quantity_events from public,anon,authenticated;

create or replace function public.gs_record_table_item_delivery_quantity(
 p_order_item_id bigint,p_action text,p_quantity integer)
returns table(picked integer,delivered integer,remaining_to_pick integer,remaining_to_deliver integer)
language plpgsql volatile security definer set search_path='' as $$
declare v_item public.gs_order_items%rowtype; v_job public.gs_table_service_jobs%rowtype;
 v_fulfillment text; v_picked integer; v_delivered integer; v_status text;
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_edit') or
  public.gs_can_access('table_orders','can_edit')) then
  raise exception 'Not authorized to record delivery';
 end if;
 if p_action not in ('picked_up','delivered') or p_quantity is null
    or p_quantity<1 or p_quantity>999 then
  raise exception 'Invalid action or quantity';
 end if;
 -- Parent-item lock serializes concurrent quantity changes and legacy transitions.
 select * into v_item from public.gs_order_items where id=p_order_item_id for update;
 if not found then raise exception 'Order item not found'; end if;
 select o.status into v_status from public.gs_orders o where o.id=v_item.order_id;
 if v_status is null or v_status in ('cancelled','draft') then
  raise exception 'Order not eligible for delivery'; end if;
 select f.status into v_fulfillment from public.gs_table_item_fulfillment f
 where f.order_item_id=p_order_item_id for update;
 if v_fulfillment is null or v_fulfillment not in ('prepared','picked_up') then
  raise exception 'Item must be prepared or partially picked up'; end if;
 select * into v_job from public.gs_table_service_jobs j
 where j.kind='deliver_items' and j.order_item_id=p_order_item_id
 and j.status in ('assigned','in_progress') for update;
 if not found or v_job.assigned_to is distinct from auth.uid() then
  raise exception 'Active delivery job must be assigned to this employee'; end if;
 insert into public.gs_table_item_delivery_quantities(order_item_id)
 values(p_order_item_id) on conflict(order_item_id) do nothing;
 select q.picked_quantity,q.delivered_quantity into v_picked,v_delivered
 from public.gs_table_item_delivery_quantities q
 where q.order_item_id=p_order_item_id for update;
 if p_action='picked_up' then
  if v_fulfillment='picked_up' and v_picked=0 then
   raise exception 'Legacy pickup detected; partial ledger cannot start'; end if;
  if v_picked+p_quantity>v_item.quantity then
   raise exception 'Pickup exceeds ordered quantity'; end if;
  v_picked:=v_picked+p_quantity;
 else
  if v_delivered+p_quantity>v_picked then
   raise exception 'Cannot deliver more than picked up'; end if;
  v_delivered:=v_delivered+p_quantity;
 end if;
 update public.gs_table_item_delivery_quantities
 set picked_quantity=v_picked,delivered_quantity=v_delivered,updated_at=now()
 where order_item_id=p_order_item_id;
 insert into public.gs_table_item_delivery_quantity_events(
  order_item_id,job_id,event_type,quantity,actor)
 values(p_order_item_id,v_job.id,p_action,p_quantity,auth.uid());
 if p_action='picked_up' then
  if v_job.status='assigned' then
   update public.gs_table_service_jobs set status='in_progress' where id=v_job.id;
   insert into public.gs_table_service_job_events(job_id,event_kind,actor,recipient,details)
   values(v_job.id,'job_in_progress',auth.uid(),v_job.created_by,
    jsonb_build_object('order_item_id',p_order_item_id,'partial_quantity',true));
  end if;
  if v_fulfillment='prepared' then
   update public.gs_table_item_fulfillment
   set status='picked_up',picked_by=auth.uid(),updated_at=now()
   where order_item_id=p_order_item_id;
   insert into public.gs_table_item_fulfillment_events(order_item_id,from_status,to_status,actor)
   values(p_order_item_id,'prepared','picked_up',auth.uid());
  end if;
 elsif v_delivered=v_item.quantity then
  update public.gs_table_item_fulfillment
  set status='delivered',delivered_by=auth.uid(),updated_at=now()
  where order_item_id=p_order_item_id;
  insert into public.gs_table_item_fulfillment_events(order_item_id,from_status,to_status,actor)
  values(p_order_item_id,'picked_up','delivered',auth.uid());
  update public.gs_table_service_jobs set status='completed',completed_at=now()
  where id=v_job.id;
  insert into public.gs_table_service_job_events(job_id,event_kind,actor,recipient,details)
  values(v_job.id,'job_completed',auth.uid(),v_job.created_by,
   jsonb_build_object('order_item_id',p_order_item_id,'confirmed_delivery',true,
                      'quantity',v_delivered));
 end if;
 return query select v_picked,v_delivered,v_item.quantity-v_picked,v_item.quantity-v_delivered;
end; $$;
revoke all on function public.gs_record_table_item_delivery_quantity(bigint,text,integer) from public,anon;
grant execute on function public.gs_record_table_item_delivery_quantity(bigint,text,integer) to authenticated;

-- Legacy endpoint must not close jobs that have quantity-ledger activity.
-- Preserve original Upgrade 191 function, inserting a guard in Upgrade 217
-- through the replacement below.
create or replace function public.gs_advance_table_item_fulfillment(
 p_order_item_id bigint,p_expected_status text,p_next_status text)
returns text language plpgsql volatile security definer set search_path='' as $$
declare v_old text; v_order bigint; v_status text;
 v_job public.gs_table_service_jobs%rowtype;
 v_job_count integer;
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
 if p_next_status in ('picked_up','delivered') and exists (
  select 1 from public.gs_table_item_delivery_quantity_events
  where order_item_id=p_order_item_id) then
  raise exception 'Use quantity-aware delivery workflow for this item';
 end if;
 -- Only the employee assigned to the matching delivery job may pick up
 -- or deliver the item. Prevent duplicate or ambiguous job linkage.
 if p_next_status in ('picked_up','delivered') then
  select count(*) into v_job_count from public.gs_table_service_jobs j
   where j.kind='deliver_items'
   and j.order_item_id=p_order_item_id
   and j.status not in ('cancelled');
  if v_job_count<>1 then
   raise exception 'Expected exactly one active delivery job';
  end if;
  select * into v_job from public.gs_table_service_jobs j
   where j.kind='deliver_items'
   and j.order_item_id=p_order_item_id
   and j.status not in ('cancelled') for update;
  if v_job.assigned_to is distinct from auth.uid() or
    v_job.status not in ('assigned','in_progress') then
   raise exception 'Delivery job must be assigned to this employee';
  end if;
 end if;
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
 if p_next_status='picked_up' and v_job.status='assigned' then
  update public.gs_table_service_jobs set status='in_progress'
   where id=v_job.id;
  insert into public.gs_table_service_job_events(
   job_id,event_kind,actor,recipient,details)
  values(v_job.id,'job_in_progress',auth.uid(),v_job.created_by,
   jsonb_build_object('order_item_id',p_order_item_id));
 elsif p_next_status='delivered' then
  update public.gs_table_service_jobs set status='completed',completed_at=now()
   where id=v_job.id;
  insert into public.gs_table_service_job_events(
   job_id,event_kind,actor,recipient,details)
  values(v_job.id,'job_completed',auth.uid(),v_job.created_by,
   jsonb_build_object('order_item_id',p_order_item_id,
    'confirmed_delivery',true));
 end if;
 return p_next_status;
end; $$;
revoke all on function public.gs_advance_table_item_fulfillment(bigint,text,text)
 from public,anon;
grant execute on function public.gs_advance_table_item_fulfillment(bigint,text,text)
 to authenticated;
