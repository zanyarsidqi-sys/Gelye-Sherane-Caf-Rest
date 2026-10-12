-- Upgrade 1194: validated customer calls feed the existing Kitchen service task queue.
-- Cashier/staff creation is already supported by gs_create_service_task with table_orders.can_edit.
-- A customer cannot write service tasks directly: only the existing visit-scoped
-- gs_customer_request_employee RPC can insert a customer call.
alter table public.gs_cafe_service_tasks alter column requested_by drop not null;
alter table public.gs_cafe_service_tasks
  add column if not exists source_call_id uuid references public.gs_customer_staff_calls(id);
create unique index if not exists gs_service_task_source_call_unique
  on public.gs_cafe_service_tasks(source_call_id) where source_call_id is not null;
alter table public.gs_cafe_service_task_events alter column actor_id drop not null;

create or replace function public.gs_bridge_customer_call_to_service_task()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_task_id bigint;
declare v_table_label text;
declare v_type text;
begin
  if new.call_type not in ('pick_dishes','clean_table') then return new; end if;
  select 'Table ' || t.table_number::text into v_table_label
    from public.gs_cafe_tables t where t.id = new.table_id;
  if v_table_label is null then raise exception 'Table not found'; end if;
  v_type := case when new.call_type = 'pick_dishes'
            then 'dish_pickup' else 'table_cleaning' end;
  insert into public.gs_cafe_service_tasks
    (table_label,task_type,notes,requested_by,source_call_id)
  values (left(v_table_label,80),v_type,
          nullif(left(btrim(new.note),500),''),auth.uid(),new.id)
  on conflict do nothing returning id into v_task_id;
  if v_task_id is not null then
    insert into public.gs_cafe_service_task_events
      (task_id,event_type,actor_id,notes)
    values (v_task_id,'customer_requested',auth.uid(),
            'Validated table visit request');
  end if;
  return new;
end;
$$;
drop trigger if exists gs_bridge_customer_call_to_service_task
  on public.gs_customer_staff_calls;
create trigger gs_bridge_customer_call_to_service_task
  after insert on public.gs_customer_staff_calls
  for each row execute function public.gs_bridge_customer_call_to_service_task();
revoke all on function public.gs_bridge_customer_call_to_service_task()
  from public,anon,authenticated;
