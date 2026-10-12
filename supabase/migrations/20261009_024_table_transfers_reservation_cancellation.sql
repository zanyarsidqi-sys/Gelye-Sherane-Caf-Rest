-- Phase 3: authorized table transfer and reservation cancellation.
-- Apply after migrations 018 and 023.
create table if not exists public.gs_table_transfer_audit (
 id bigint generated always as identity primary key,
 from_table integer not null, to_table integer not null,
 transferred_orders integer not null, actor uuid not null,
 created_at timestamptz not null default now()
);
alter table public.gs_table_transfer_audit enable row level security;
revoke all on public.gs_table_transfer_audit from public;

create or replace function public.gs_transfer_cafe_table(p_from integer, p_to integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare src public.gs_cafe_tables%rowtype; dst public.gs_cafe_tables%rowtype; n integer;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then raise exception 'Permission denied'; end if;
 if p_from is null or p_to is null or p_from=p_to then raise exception 'Select different tables'; end if;
 -- Stable lock order prevents deadlocks between simultaneous transfers.
 perform 1 from public.gs_cafe_tables where table_number in (p_from,p_to) order by table_number for update;
 select * into src from public.gs_cafe_tables where table_number=p_from;
 select * into dst from public.gs_cafe_tables where table_number=p_to;
 if src.id is null or dst.id is null then raise exception 'Table not found'; end if;
 if not src.occupied then raise exception 'Source table is not occupied'; end if;
 if dst.occupied then raise exception 'Destination table must be available'; end if;
 if src.guests > dst.capacity then raise exception 'Destination table has insufficient capacity'; end if;
 -- Avoid moving a reservation into a table currently reserved under matching numeric label.
 if exists(select 1 from public.gs_public_reservation_requests r
   join public.gs_reservable_tables t on t.id=r.assigned_table_id
   where r.status='approved' and t.table_label=p_to::text
   and now() >= r.requested_at and now() < r.requested_at+make_interval(mins=>r.duration_minutes))
 then raise exception 'Destination table has an active reservation'; end if;
 update public.gs_orders set destination=p_to::text
 where is_motel=false and destination=p_from::text and status in ('new','preparing','ready');
 get diagnostics n=row_count;
 update public.gs_cafe_tables set occupied=true, guests=src.guests,
 tourism_mode=src.tourism_mode, updated_at=now(), updated_by=auth.uid() where id=dst.id;
 update public.gs_cafe_tables set occupied=false, guests=0,
 tourism_mode=false, updated_at=now(), updated_by=auth.uid() where id=src.id;
 insert into public.gs_table_transfer_audit(from_table,to_table,transferred_orders,actor)
 values(p_from,p_to,n,auth.uid());
 return n;
end $$;
revoke all on function public.gs_transfer_cafe_table(integer,integer) from public;
grant execute on function public.gs_transfer_cafe_table(integer,integer) to authenticated;

create or replace function public.gs_cancel_reservation(p_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare previous text;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then raise exception 'Permission denied'; end if;
 perform pg_advisory_xact_lock(721903,1);
 select status into previous from public.gs_public_reservation_requests where id=p_id for update;
 if previous is null then raise exception 'Reservation not found'; end if;
 if previous not in ('pending','approved') then raise exception 'Reservation cannot be cancelled from this status'; end if;
 update public.gs_public_reservation_requests set status='cancelled',assigned_table_id=null where id=p_id;
 insert into public.gs_public_request_review_audit(request_type,request_id,old_status,new_status,actor)
 values('reservation',p_id,previous,'cancelled',auth.uid());
 return 'cancelled';
end $$;
revoke all on function public.gs_cancel_reservation(uuid) from public;
grant execute on function public.gs_cancel_reservation(uuid) to authenticated;
