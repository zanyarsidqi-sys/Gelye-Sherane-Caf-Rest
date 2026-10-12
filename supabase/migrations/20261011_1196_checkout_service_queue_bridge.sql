-- Upgrade 1196: mirror authoritative physical checkout tasks into Kitchen service queue.
-- Existing gs_mark_table_departed_for_cleaning creates gs_table_service_tasks.
-- Preserve financial settlement checks and the existing physical table release gate.
-- This bridge never updates table occupancy, payment state, or visit status.

alter table public.gs_cafe_service_tasks
  add column if not exists source_table_service_task_id bigint
    references public.gs_table_service_tasks(id);
create unique index if not exists gs_cafe_service_tasks_source_table_task_unique
  on public.gs_cafe_service_tasks(source_table_service_task_id)
  where source_table_service_task_id is not null;

create or replace function public.gs_mirror_checkout_task_to_kitchen_queue()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_type text;
declare v_label text;
declare v_id bigint;
begin
  -- Only physical cleanup tasks. Ignore unrelated table requests.
  if new.request_type not in ('table_cleaning','dish_pickup','shisha_pickup')
     or new.status in ('completed','cancelled') then
    return new;
  end if;
  -- Keep the source task authoritative for table-release readiness.
  v_type := case when new.request_type = 'shisha_pickup' then 'dish_pickup'
                 else new.request_type end;
  select t.table_number::text into v_label
    from public.gs_cafe_tables t where t.id = new.table_id;
  if v_label is null then return new; end if;
  insert into public.gs_cafe_service_tasks
    (table_label, task_type, notes, requested_by, source_table_service_task_id)
  values (left(v_label,80),v_type,
          left(coalesce(new.notes,'') || case when new.request_type='shisha_pickup'
             then ' [Shisha pickup]' else '' end,500),
          new.created_by,new.id)
  on conflict do nothing
  returning id into v_id;
  if v_id is not null then
    insert into public.gs_cafe_service_task_events
      (task_id,event_type,actor_id,notes)
    values (v_id,'checkout_task_queued',new.created_by,
            'Linked to physical table-service task ' || new.id::text);
  end if;
  return new;
end;
$$;
drop trigger if exists gs_mirror_checkout_task_to_kitchen_queue
  on public.gs_table_service_tasks;
create trigger gs_mirror_checkout_task_to_kitchen_queue
  after insert on public.gs_table_service_tasks
  for each row execute function public.gs_mirror_checkout_task_to_kitchen_queue();
revoke all on function public.gs_mirror_checkout_task_to_kitchen_queue()
  from public,anon,authenticated;

-- When a mirrored Kitchen task is completed, complete its authoritative
-- physical task too, but never alter table occupancy or release the table.
create or replace function public.gs_sync_kitchen_cleanup_completion()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.source_table_service_task_id is null or new.status = old.status then
    return new;
  end if;
  if new.status = 'completed' then
    update public.gs_table_service_tasks
       set status='completed', completed_at=coalesce(new.completed_at,transaction_timestamp()),
           updated_at=transaction_timestamp()
     where id=new.source_table_service_task_id
       and status not in ('completed','cancelled');
  elsif new.status = 'cancelled' then
    -- Do not silently cancel mandatory physical cleaning; an authorized
    -- table manager must explicitly handle any physical-task cancellation.
    null;
  end if;
  return new;
end;
$$;
drop trigger if exists gs_sync_kitchen_cleanup_completion
  on public.gs_cafe_service_tasks;
create trigger gs_sync_kitchen_cleanup_completion
  after update of status on public.gs_cafe_service_tasks
  for each row execute function public.gs_sync_kitchen_cleanup_completion();
revoke all on function public.gs_sync_kitchen_cleanup_completion()
  from public,anon,authenticated;
