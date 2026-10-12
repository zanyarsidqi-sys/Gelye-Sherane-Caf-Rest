-- Upgrade 1204: replacement-specific preparation and delivery queue.
-- Financial corrections are never modified by these operational transitions.
alter table public.gs_cafe_correction_station_revisions
 add column if not exists preparation_state text not null default 'awaiting_acceptance'
 check (preparation_state in ('awaiting_acceptance','accepted','preparing','ready'));
alter table public.gs_cafe_correction_station_revisions
 add column if not exists preparation_accepted_at timestamptz,
 add column if not exists preparation_started_at timestamptz,
 add column if not exists preparation_ready_at timestamptz,
 add column if not exists preparation_employee uuid references auth.users(id);
create table if not exists public.gs_cafe_replacement_delivery_tasks (
 revision_id bigint primary key references public.gs_cafe_correction_station_revisions(id) on delete restrict,
 created_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id), assigned_by uuid references auth.users(id),
 assigned_at timestamptz, accepted_at timestamptz,
 picked_up_at timestamptz, delivered_at timestamptz,
 updated_at timestamptz not null default transaction_timestamp()
);
create table if not exists public.gs_cafe_replacement_delivery_events (
 id bigint generated always as identity primary key,
 revision_id bigint not null references public.gs_cafe_correction_station_revisions(id),
 actor_id uuid references auth.users(id),
 event_kind text not null check(event_kind in ('ready','assigned','accepted','picked_up','delivered')),
 event_at timestamptz not null default transaction_timestamp(),
 assigned_to uuid references auth.users(id)
);
alter table public.gs_cafe_replacement_delivery_tasks enable row level security;
alter table public.gs_cafe_replacement_delivery_events enable row level security;
revoke all on public.gs_cafe_replacement_delivery_tasks,public.gs_cafe_replacement_delivery_events from public,anon,authenticated;

create or replace function public.gs_transition_replacement_preparation(p_revision_id bigint,p_action text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.gs_cafe_correction_station_revisions%rowtype;
begin
 select * into r from public.gs_cafe_correction_station_revisions where id=p_revision_id for update;
 if not found or r.revision_kind<>'prepare_replacement' then raise exception 'Replacement notice not found'; end if;
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit')
 or not public.gs_can_work_station(r.station_key) then raise exception 'Authorized station employee required'; end if;
 if r.state<>'acknowledged' then raise exception 'Acknowledge replacement notice first'; end if;
 if (p_action='accept' and r.preparation_state='awaiting_acceptance') then
   update public.gs_cafe_correction_station_revisions set preparation_state='accepted',preparation_accepted_at=transaction_timestamp(),preparation_employee=auth.uid() where id=r.id;
 elsif p_action='prepare' and r.preparation_state='accepted' then
   update public.gs_cafe_correction_station_revisions set preparation_state='preparing',preparation_started_at=transaction_timestamp(),preparation_employee=auth.uid() where id=r.id;
 elsif p_action='ready' and r.preparation_state='preparing' then
   update public.gs_cafe_correction_station_revisions set preparation_state='ready',preparation_ready_at=transaction_timestamp(),preparation_employee=auth.uid() where id=r.id;
   insert into public.gs_cafe_replacement_delivery_tasks(revision_id) values(r.id) on conflict do nothing;
   insert into public.gs_cafe_replacement_delivery_events(revision_id,actor_id,event_kind) values(r.id,auth.uid(),'ready');
 else raise exception 'Invalid replacement preparation transition'; end if;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'kitchen','replacement_preparation_'||p_action,r.id::text,jsonb_build_object('station',r.station_key));
end; $$;
revoke all on function public.gs_transition_replacement_preparation(bigint,text) from public,anon;
grant execute on function public.gs_transition_replacement_preparation(bigint,text) to authenticated;

-- A separate queue prevents replacement notices from being confused with original station tickets.
create or replace function public.gs_list_replacement_delivery_tasks()
returns table(revision_id bigint,order_id bigint,station_key text,product_name text,quantity integer,
 ready_at timestamptz,assigned_to uuid,accepted_at timestamptz,picked_up_at timestamptz,delivered_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select r.id,r.order_id,r.station_key,p.name,r.quantity,r.preparation_ready_at,
 d.assigned_to,d.accepted_at,d.picked_up_at,d.delivered_at
 from public.gs_cafe_replacement_delivery_tasks d
 join public.gs_cafe_correction_station_revisions r on r.id=d.revision_id
 join public.gs_order_items i on i.id=r.order_item_id
 join public.gs_menu_products p on p.id=i.product_id
 where d.delivered_at is null and (d.assigned_to=auth.uid()
 or exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 or (d.assigned_to is null and public.gs_can_work_station(r.station_key)))
 order by r.preparation_ready_at,r.id limit 200;
end; $$;
revoke all on function public.gs_list_replacement_delivery_tasks() from public,anon;
grant execute on function public.gs_list_replacement_delivery_tasks() to authenticated;

create or replace function public.gs_transition_replacement_delivery(p_revision_id bigint,p_action text,p_employee_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.gs_cafe_correction_station_revisions%rowtype; d public.gs_cafe_replacement_delivery_tasks%rowtype;
begin
 select * into r from public.gs_cafe_correction_station_revisions where id=p_revision_id;
 select * into d from public.gs_cafe_replacement_delivery_tasks where revision_id=p_revision_id for update;
 if not found or r.preparation_state<>'ready' or d.delivered_at is not null then raise exception 'Active ready replacement required'; end if;
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then raise exception 'Kitchen edit permission required'; end if;
 if p_action='assign' then
   if not exists(select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active) then raise exception 'Supervisor required'; end if;
   if p_employee_id is null or not exists(select 1 from public.gs_cafe_station_employee_assignments a where a.station_key=r.station_key and a.employee_id=p_employee_id and a.active) then raise exception 'Active station employee required'; end if;
   if d.picked_up_at is not null then raise exception 'Cannot reassign after pickup'; end if;
   update public.gs_cafe_replacement_delivery_tasks set assigned_to=p_employee_id,assigned_by=auth.uid(),assigned_at=transaction_timestamp(),accepted_at=null,updated_at=transaction_timestamp() where revision_id=r.id;
 elsif p_action='accept' and d.assigned_to=auth.uid() and d.accepted_at is null then
   update public.gs_cafe_replacement_delivery_tasks set accepted_at=transaction_timestamp(),updated_at=transaction_timestamp() where revision_id=r.id;
 elsif p_action='pickup' and d.assigned_to=auth.uid() and d.accepted_at is not null and d.picked_up_at is null then
   update public.gs_cafe_replacement_delivery_tasks set picked_up_at=transaction_timestamp(),updated_at=transaction_timestamp() where revision_id=r.id;
 elsif p_action='deliver' and d.assigned_to=auth.uid() and d.picked_up_at is not null then
   update public.gs_cafe_replacement_delivery_tasks set delivered_at=transaction_timestamp(),updated_at=transaction_timestamp() where revision_id=r.id;
 else raise exception 'Invalid or unauthorized delivery transition'; end if;
 insert into public.gs_cafe_replacement_delivery_events(revision_id,actor_id,event_kind,assigned_to)
 values(r.id,auth.uid(),case when p_action='pickup' then 'picked_up' else case when p_action='deliver' then 'delivered' else p_action end end,
 case when p_action='assign' then p_employee_id else d.assigned_to end);
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'kitchen','replacement_delivery_'||p_action,r.id::text,jsonb_build_object('assigned_to',case when p_action='assign' then p_employee_id else d.assigned_to end));
end; $$;
revoke all on function public.gs_transition_replacement_delivery(bigint,text,uuid) from public,anon;
grant execute on function public.gs_transition_replacement_delivery(bigint,text,uuid) to authenticated;

-- Add preparation state for employee workflow without changing existing column order.
drop function if exists public.gs_kitchen_correction_revision_queue();
create function public.gs_kitchen_correction_revision_queue()
returns table(revision_id bigint,correction_id bigint,order_id bigint,station_key text,
 revision_kind text,order_item_id bigint,product_name text,quantity integer,
 state text,created_at timestamptz,preparation_state text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then raise exception 'Kitchen view permission required'; end if;
 return query select r.id,r.correction_id,r.order_id,r.station_key,r.revision_kind,
 r.order_item_id,p.name,r.quantity,r.state,r.created_at,r.preparation_state
 from public.gs_cafe_correction_station_revisions r
 join public.gs_order_items i on i.id=r.order_item_id
 join public.gs_menu_products p on p.id=i.product_id
 where public.gs_can_work_station(r.station_key) or exists(
 select 1 from public.gs_cafe_station_supervisors s where s.employee_id=auth.uid() and s.active)
 order by (r.state='pending') desc,r.created_at desc limit 250;
end; $$;
revoke all on function public.gs_kitchen_correction_revision_queue() from public,anon;
grant execute on function public.gs_kitchen_correction_revision_queue() to authenticated;
