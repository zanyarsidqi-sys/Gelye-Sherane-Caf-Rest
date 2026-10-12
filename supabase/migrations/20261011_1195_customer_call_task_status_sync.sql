-- Upgrade 1195: synchronize visit-scoped customer calls and service tasks.
-- Fix the 1194 bridge prerequisite: the original call type constraint/RPC
-- did not accept pick_dishes or clean_table.
alter table public.gs_customer_staff_calls
  drop constraint if exists gs_customer_staff_calls_call_type_check;
alter table public.gs_customer_staff_calls
  add constraint gs_customer_staff_calls_call_type_check
  check (call_type in ('waiter','cashier','shisha','supervisor','any','pick_dishes','clean_table'));

-- Preserve existing session, occupancy, open-visit, active-call and rate checks.
create or replace function public.gs_customer_request_employee(
 p_session_token uuid,p_call_type text,p_note text default '')
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.gs_customer_visit_sessions%rowtype; v_id uuid;
begin
 select x.* into s from public.gs_customer_visit_sessions x
 join public.gs_cafe_tables t on t.id=x.table_id
 join public.gs_table_visits v on v.id=x.visit_id and v.table_id=x.table_id
 where x.session_token=p_session_token and x.revoked_at is null and x.expires_at>now()
 and t.occupied=true and v.status='open' for update of x;
 if not found then raise exception 'Visit authorization required'; end if;
 if p_call_type not in ('waiter','cashier','shisha','supervisor','any','pick_dishes','clean_table')
 or length(coalesce(p_note,''))>300 then raise exception 'Invalid assistance request'; end if;
 if exists(select 1 from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.table_id=s.table_id and c.status in ('waiting','accepted','on_way')) then
  raise exception 'An assistance request is already active'; end if;
 if (select count(*) from public.gs_customer_staff_calls c where c.visit_id=s.visit_id
 and c.requested_at>now()-interval '1 hour')>=5 then
  raise exception 'Too many requests for this visit'; end if;
 insert into public.gs_customer_staff_calls(table_id,visit_id,call_type,note)
 values(s.table_id,s.visit_id,p_call_type,trim(coalesce(p_note,''))) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_customer_request_employee(uuid,text,text) from public;
grant execute on function public.gs_customer_request_employee(uuid,text,text) to anon,authenticated;

-- Both triggers operate in the same transaction, so no half-completed state.
-- Only status changes trigger writes; equal status does not recurse.
create or replace function public.gs_sync_service_task_to_customer_call()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_status text;
begin
 if new.source_call_id is null or new.status = old.status then return new; end if;
 select c.status into v_status from public.gs_customer_staff_calls c
 where c.id=new.source_call_id for update;
 if not found or v_status in ('completed','cancelled') then return new; end if;
 if new.status='completed' then
   update public.gs_customer_staff_calls
   set status='completed', completed_at=coalesce(new.completed_at,transaction_timestamp()),
       assigned_employee=coalesce(new.assigned_to,assigned_employee),updated_at=transaction_timestamp()
   where id=new.source_call_id and status not in ('completed','cancelled');
 elsif new.status='cancelled' then
   update public.gs_customer_staff_calls
   set status='cancelled',completed_at=transaction_timestamp(),updated_at=transaction_timestamp()
   where id=new.source_call_id and status not in ('completed','cancelled');
 elsif new.status in ('assigned','accepted') and v_status='waiting' then
   update public.gs_customer_staff_calls
   set status='accepted',accepted_at=coalesce(new.accepted_at,new.assigned_at,transaction_timestamp()),
       assigned_employee=new.assigned_to,updated_at=transaction_timestamp()
   where id=new.source_call_id and status='waiting';
 end if;
 return new;
end $$;
drop trigger if exists gs_sync_service_task_to_customer_call on public.gs_cafe_service_tasks;
create trigger gs_sync_service_task_to_customer_call
 after update of status on public.gs_cafe_service_tasks
 for each row execute function public.gs_sync_service_task_to_customer_call();

create or replace function public.gs_sync_customer_call_to_service_task()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_task public.gs_cafe_service_tasks%rowtype;
begin
 if new.status=old.status then return new; end if;
 select * into v_task from public.gs_cafe_service_tasks
 where source_call_id=new.id for update;
 if not found or v_task.status in ('completed','cancelled') then return new; end if;
 if new.status='completed' then
   update public.gs_cafe_service_tasks
   set status='completed',completed_at=coalesce(new.completed_at,transaction_timestamp()),
       updated_at=transaction_timestamp() where id=v_task.id;
 elsif new.status='cancelled' then
   update public.gs_cafe_service_tasks
   set status='cancelled',cancelled_at=transaction_timestamp(),
       updated_at=transaction_timestamp() where id=v_task.id;
 else
   return new;
 end if;
 insert into public.gs_cafe_service_task_events(task_id,event_type,actor_id,notes)
 values(v_task.id,'customer_call_' || new.status,auth.uid(),
        'Synchronized from customer call status');
 return new;
end $$;
drop trigger if exists gs_sync_customer_call_to_service_task on public.gs_customer_staff_calls;
create trigger gs_sync_customer_call_to_service_task
 after update of status on public.gs_customer_staff_calls
 for each row execute function public.gs_sync_customer_call_to_service_task();
revoke all on function public.gs_sync_service_task_to_customer_call() from public,anon,authenticated;
revoke all on function public.gs_sync_customer_call_to_service_task() from public,anon,authenticated;
