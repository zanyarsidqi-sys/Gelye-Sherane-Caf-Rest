-- Upgrade 294: fail-closed protection for unimplemented multi-table and whole-venue approvals.
-- No unsafe reservation may be confirmed until full cross-module locking is implemented.
create or replace function public.gs_event_scope_approval_guard()
returns trigger language plpgsql set search_path = '' as $$
declare v_count integer;
begin
 if new.status = 'approved' and old.status is distinct from 'approved' then
   select count(*) into v_count from public.gs_event_requested_tables where event_id = new.id;
   if new.venue_scope = 'whole_venue' then
     raise exception 'Whole-venue approval is unavailable until exclusive venue locking is installed' using errcode='23514';
   end if;
   if v_count > 1 then
     raise exception 'Multiple-table approval is unavailable until all-table conflict locking is installed' using errcode='23514';
   end if;
   if v_count = 1 and (new.requested_table_id is null or
       not exists (select 1 from public.gs_event_requested_tables t where t.event_id=new.id and t.table_id=new.requested_table_id)) then
     raise exception 'Requested table references are inconsistent' using errcode='23514';
   end if;
 end if;
 return new;
end $$;
drop trigger if exists gs_event_scope_approval_guard_trigger on public.gs_event_reservations;
create trigger gs_event_scope_approval_guard_trigger before update of status
 on public.gs_event_reservations for each row execute function public.gs_event_scope_approval_guard();
-- Restrict all table assignments to a single authoritative staff RPC.
create or replace function public.gs_staff_set_event_requested_tables(p_event_id uuid,p_table_ids uuid[])
returns integer language plpgsql security definer set search_path = '' as $$
declare e public.gs_event_reservations%rowtype; v_id uuid; v_count integer; v_seats integer;
begin
 if auth.uid() is null or not public.cafe_can_manage_website('edit') then
   raise exception 'Not authorized' using errcode='42501'; end if;
 select * into e from public.gs_event_reservations where id=p_event_id for update;
 if not found or e.status <> 'pending_admin' then raise exception 'Event is not editable'; end if;
 if e.venue_scope = 'whole_venue' then
   if coalesce(array_length(p_table_ids,1),0)<>0 then raise exception 'Whole-venue requests cannot specify tables'; end if;
   delete from public.gs_event_requested_tables where event_id=e.id;
   update public.gs_event_reservations set requested_table_id=null,updated_at=now() where id=e.id;
   return 0;
 end if;
 v_count:=coalesce(array_length(p_table_ids,1),0);
 if v_count<1 or v_count>30 or (select count(distinct x) from unnest(p_table_ids) x)<>v_count then
   raise exception 'Select between 1 and 30 unique tables'; end if;
 -- Lock selected table rows in stable order, validating existence and capacity.
 perform 1 from public.gs_reservable_tables t where t.id=any(p_table_ids) and t.enabled order by t.id for update;
 if (select count(*) from public.gs_reservable_tables t where t.id=any(p_table_ids) and t.enabled)<>v_count then
   raise exception 'A requested table is unavailable'; end if;
 select sum(t.seats) into v_seats from public.gs_reservable_tables t where t.id=any(p_table_ids);
 if v_seats<e.guest_count then raise exception 'Insufficient combined table capacity'; end if;
 delete from public.gs_event_requested_tables where event_id=e.id;
 insert into public.gs_event_requested_tables(event_id,table_id)
 select e.id,x from unnest(p_table_ids) x;
 update public.gs_event_reservations set requested_table_id=case when v_count=1 then p_table_ids[1] else null end,
 updated_at=now() where id=e.id;
 return v_count;
end $$;
revoke all on function public.gs_staff_set_event_requested_tables(uuid,uuid[]) from public,anon;
grant execute on function public.gs_staff_set_event_requested_tables(uuid,uuid[]) to authenticated;
