-- Upgrade 219: one authoritative pickup/delivery path.
-- Existing historical whole-item deliveries remain historical; no synthetic events are invented.
-- Replace the legacy fulfillment RPC to allow only kitchen progression, not pickup/delivery.
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
 if p_next_status in ('picked_up','delivered') then
  raise exception 'Pickup and delivery must use the quantity-aware handover workflow';
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

-- Quantity snapshots refuse to present a misleading zero-picked state for legacy
-- already-picked items. Such jobs require an explicit audited reconciliation.
create or replace function public.gs_my_table_delivery_quantity_status(p_job_id bigint)
returns table(order_item_id bigint, ordered_quantity integer,
 picked_quantity integer, delivered_quantity integer,
 remaining_to_pick integer, available_to_deliver integer,
 remaining_to_deliver integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('tables','can_edit') or
   public.gs_can_access('table_orders','can_edit')) then
  raise exception 'Not authorized to view delivery quantities';
 end if;
 if exists (
  select 1 from public.gs_table_service_jobs j
  join public.gs_table_item_fulfillment f on f.order_item_id=j.order_item_id
  left join public.gs_table_item_delivery_quantities q on q.order_item_id=j.order_item_id
  where j.id=p_job_id and j.kind='deliver_items' and j.assigned_to=auth.uid()
    and f.status='picked_up' and coalesce(q.picked_quantity,0)=0
 ) then
  raise exception 'Legacy whole-item pickup needs manager reconciliation before quantity handover';
 end if;
 return query
 select i.id,i.quantity::integer,
   coalesce(q.picked_quantity,0)::integer,
   coalesce(q.delivered_quantity,0)::integer,
   (i.quantity-coalesce(q.picked_quantity,0))::integer,
   (coalesce(q.picked_quantity,0)-coalesce(q.delivered_quantity,0))::integer,
   (i.quantity-coalesce(q.delivered_quantity,0))::integer
 from public.gs_table_service_jobs j
 join public.gs_order_items i on i.id=j.order_item_id
 left join public.gs_table_item_delivery_quantities q on q.order_item_id=i.id
 where j.id=p_job_id and j.kind='deliver_items'
   and j.status in ('assigned','in_progress') and j.assigned_to=auth.uid();
end; $$;
revoke all on function public.gs_my_table_delivery_quantity_status(bigint) from public,anon;
grant execute on function public.gs_my_table_delivery_quantity_status(bigint) to authenticated;
