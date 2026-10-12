-- Upgrade 191: explicit relational item-to-delivery-job linkage.
-- Fail closed if historical duplicates exist; repair manually before deployment.
alter table public.gs_table_service_jobs
 add column if not exists order_item_id bigint references public.gs_order_items(id);
-- Backfill only the legacy exact generated details pattern.
update public.gs_table_service_jobs j
set order_item_id=substring(j.details from '^Order item #([0-9]+)$')::bigint
where j.kind='deliver_items' and j.order_item_id is null
 and j.details ~ '^Order item #[0-9]+$'
 and exists (select 1 from public.gs_order_items i
   where i.id=substring(j.details from '^Order item #([0-9]+)$')::bigint);
-- Never silently bind an ambiguous job or one with an unrecognized reference.
do $$ begin
 if exists(select 1 from public.gs_table_service_jobs
    where kind='deliver_items' and status<>'cancelled'
    and order_item_id is null) then
   raise exception 'Unlinked active delivery jobs: resolve before migration';
 end if;
 if exists(select 1 from public.gs_table_service_jobs
    where kind='deliver_items' and status<>'cancelled'
    group by order_item_id having count(*)>1) then
   raise exception 'Duplicate active delivery jobs: resolve before migration';
 end if;
end $$;
create unique index if not exists gs_one_active_delivery_job_per_item
 on public.gs_table_service_jobs(order_item_id)
 where kind='deliver_items' and status<>'cancelled';
-- No non-delivery job may point to an item.
alter table public.gs_table_service_jobs
 add constraint gs_delivery_job_item_link_check
 check (order_item_id is null or kind='deliver_items');

create or replace function public.gs_notify_item_fulfillment()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_table_number integer; v_visit bigint; v_job bigint; v_creator uuid;
begin
 select t.table_number,v.id into v_table_number,v_visit
 from public.gs_order_items i
 join public.gs_orders o on o.id=i.order_id
 join public.gs_table_visits v on v.id=o.table_visit_id
 join public.gs_cafe_tables t on t.id=v.table_id
 where i.id=new.order_item_id;
 -- This notification pipeline is specifically for table orders.
 if v_table_number is null then return new; end if;
 if new.to_status='prepared' then
   -- One delivery task per order item. A duplicate trigger replay cannot create another.
   select j.id into v_job from public.gs_table_service_jobs j
   where j.kind='deliver_items' and j.order_item_id=new.order_item_id
   limit 1;
   if v_job is null then
     insert into public.gs_table_service_jobs(
       table_number,visit_id,kind,details,priority,created_by,order_item_id)
     values(v_table_number,v_visit,'deliver_items',
       'Order item #'||new.order_item_id,'normal',new.actor,new.order_item_id)
     returning id into v_job;
     insert into public.gs_table_service_job_events(job_id,event_kind,actor,details)
     values(v_job,'job_created',new.actor,
       jsonb_build_object('order_item_id',new.order_item_id));
   end if;
 end if;
 insert into public.gs_table_work_notifications(
  event_type,order_item_id,job_id,table_number,actor,message)
 values('item_'||new.to_status,new.order_item_id,v_job,v_table_number,new.actor,
  'Table '||v_table_number||': item #'||new.order_item_id||' is '||
  replace(new.to_status,'_',' '))
 on conflict(event_type,order_item_id) do nothing;
 return new;
end; $$;
-- Upgrade 190: job-verified pickup/delivery and atomic job closure.
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
