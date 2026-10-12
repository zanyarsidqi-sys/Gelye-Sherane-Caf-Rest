-- Upgrade 1177: immutable, server-stamped kitchen status history.
create table if not exists public.gs_kitchen_status_history (
 id bigint generated always as identity primary key,
 order_id bigint not null references public.gs_orders(id),
 previous_status text not null,
 new_status text not null,
 changed_at timestamptz not null default transaction_timestamp(),
 changed_by uuid references auth.users(id)
);
create index if not exists gs_kitchen_status_history_order_idx
 on public.gs_kitchen_status_history(order_id, changed_at, id);
alter table public.gs_kitchen_status_history enable row level security;
revoke all on public.gs_kitchen_status_history from anon, authenticated;
create or replace function public.gs_record_kitchen_status_history()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.status is distinct from new.status then
   insert into public.gs_kitchen_status_history(order_id,previous_status,new_status,changed_by)
   values(new.id, old.status, new.status, auth.uid());
 end if;
 return new;
end;
$$;
drop trigger if exists gs_record_kitchen_status_history on public.gs_orders;
create trigger gs_record_kitchen_status_history
 after update of status on public.gs_orders for each row
 execute function public.gs_record_kitchen_status_history();
revoke all on function public.gs_record_kitchen_status_history() from public, anon, authenticated;

create or replace function public.gs_get_kitchen_status_history(p_order_id bigint)
returns table(previous_status text, new_status text, changed_at timestamptz, changed_by uuid)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Not authorized to view kitchen history';
 end if;
 if p_order_id is null or p_order_id <= 0 then
   raise exception 'Valid order ID required';
 end if;
 return query select h.previous_status,h.new_status,h.changed_at,h.changed_by
 from public.gs_kitchen_status_history h
 where h.order_id = p_order_id
 order by h.changed_at, h.id limit 500;
end;
$$;
revoke all on function public.gs_get_kitchen_status_history(bigint) from public, anon;
grant execute on function public.gs_get_kitchen_status_history(bigint) to authenticated;
