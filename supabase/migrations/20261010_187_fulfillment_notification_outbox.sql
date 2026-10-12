-- Upgrade 187: durable, permission-gated fulfillment notifications and delivery jobs.
-- Event creation is transactional with fulfillment changes; dispatch/push remains pending.
create table if not exists public.gs_table_work_notifications (
 id bigint generated always as identity primary key,
 event_type text not null,
 order_item_id bigint references public.gs_order_items(id),
 job_id bigint references public.gs_table_service_jobs(id),
 table_number integer,
 recipient_employee uuid references auth.users(id),
 actor uuid references auth.users(id),
 message text not null,
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(event_type,order_item_id)
);
create index if not exists gs_table_work_notifications_recent
 on public.gs_table_work_notifications(created_at desc);
alter table public.gs_table_work_notifications enable row level security;
revoke all on public.gs_table_work_notifications from public,anon,authenticated;

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
   where j.kind='deliver_items' and j.details=('Order item #'||new.order_item_id)
   limit 1;
   if v_job is null then
     insert into public.gs_table_service_jobs(
       table_number,visit_id,kind,details,priority,created_by)
     values(v_table_number,v_visit,'deliver_items',
       'Order item #'||new.order_item_id,'normal',new.actor)
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
drop trigger if exists gs_item_fulfillment_notify on public.gs_table_item_fulfillment_events;
create trigger gs_item_fulfillment_notify
 after insert on public.gs_table_item_fulfillment_events
 for each row execute function public.gs_notify_item_fulfillment();

create or replace function public.gs_list_table_work_notifications()
returns table(id bigint,event_type text,table_number integer,message text,
 created_at timestamptz,job_id bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
 public.gs_can_access('tables','can_view') or
 public.gs_can_access('table_orders','can_view') or
 public.gs_can_access('kitchen','can_view')) then
 raise exception 'Not authorized to view table work notifications'; end if;
 return query select n.id,n.event_type,n.table_number,n.message,n.created_at,n.job_id
 from public.gs_table_work_notifications n
 where n.recipient_employee is null or n.recipient_employee=auth.uid()
 order by n.created_at desc limit 100;
end; $$;
revoke all on function public.gs_list_table_work_notifications() from public,anon;
grant execute on function public.gs_list_table_work_notifications() to authenticated;
