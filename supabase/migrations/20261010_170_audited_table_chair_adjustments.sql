-- Upgrade 170: auditable chair add/remove, without touching orders or payments.
create table if not exists public.gs_table_chair_events (
 id bigint generated always as identity primary key,
 table_id bigint not null references public.gs_cafe_tables(id),
 table_visit_id bigint references public.gs_table_visits(id),
 old_capacity integer not null,
 new_capacity integer not null,
 delta integer not null,
 reason text not null,
 changed_by uuid not null references auth.users(id),
 changed_at timestamptz not null default now(),
 constraint gs_chair_event_delta check(new_capacity-old_capacity=delta),
 constraint gs_chair_event_capacity check(old_capacity between 1 and 50 and new_capacity between 1 and 50),
 constraint gs_chair_event_reason check(length(trim(reason))>=3)
);
create index if not exists gs_table_chair_events_history
 on public.gs_table_chair_events(table_id,changed_at desc);
alter table public.gs_table_chair_events enable row level security;
revoke all on public.gs_table_chair_events from public,anon,authenticated;
create or replace function public.gs_prevent_chair_event_changes()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Chair change audit records cannot be changed'; end; $$;
drop trigger if exists gs_chair_event_immutable on public.gs_table_chair_events;
create trigger gs_chair_event_immutable before update or delete
 on public.gs_table_chair_events for each row
 execute function public.gs_prevent_chair_event_changes();

create or replace function public.gs_adjust_table_chairs(
 p_table_number integer,p_delta integer,p_reason text)
returns table(table_number integer,old_capacity integer,new_capacity integer,event_id bigint)
language plpgsql volatile security definer set search_path='' as $$
declare v_table public.gs_cafe_tables%rowtype;
 v_visit bigint;
 v_new integer;
 v_event bigint;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Chair adjustment permission denied';
 end if;
 if p_delta is null or p_delta=0 or abs(p_delta)>20 then
  raise exception 'Chair adjustment must be between -20 and +20, excluding zero';
 end if;
 if p_reason is null or length(trim(p_reason))<3 then
  raise exception 'Reason required (at least three characters)';
 end if;
 select * into v_table from public.gs_cafe_tables t
 where t.table_number=p_table_number for update;
 if not found then raise exception 'Table not found'; end if;
 v_new:=v_table.capacity+p_delta;
 if v_new<1 or v_new>50 then
  raise exception 'Capacity must remain between 1 and 50';
 end if;
 if v_new<v_table.guests then
  raise exception 'Cannot remove chairs below current guest count (%)',v_table.guests;
 end if;
 select v.id into v_visit from public.gs_table_visits v
 where v.table_id=v_table.id and v.status<>'closed'
 order by v.opened_at desc limit 1;
 update public.gs_cafe_tables t set capacity=v_new,updated_at=now(),updated_by=auth.uid()
 where t.id=v_table.id;
 insert into public.gs_table_chair_events
  (table_id,table_visit_id,old_capacity,new_capacity,delta,reason,changed_by)
 values(v_table.id,v_visit,v_table.capacity,v_new,p_delta,trim(p_reason),auth.uid())
 returning id into v_event;
 return query select v_table.table_number,v_table.capacity,v_new,v_event;
end; $$;
revoke all on function public.gs_adjust_table_chairs(integer,integer,text) from public,anon;
grant execute on function public.gs_adjust_table_chairs(integer,integer,text) to authenticated;

create or replace function public.gs_table_chair_history(p_table_number integer)
returns table(event_id bigint,old_capacity integer,new_capacity integer,
 delta integer,reason text,changed_by uuid,changed_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_view') then
  raise exception 'Chair history access denied';
 end if;
 return query
 select e.id,e.old_capacity,e.new_capacity,e.delta,e.reason,e.changed_by,e.changed_at
 from public.gs_table_chair_events e
 join public.gs_cafe_tables t on t.id=e.table_id
 where t.table_number=p_table_number
 order by e.changed_at desc,e.id desc limit 100;
end; $$;
revoke all on function public.gs_table_chair_history(integer) from public,anon;
grant execute on function public.gs_table_chair_history(integer) to authenticated;
