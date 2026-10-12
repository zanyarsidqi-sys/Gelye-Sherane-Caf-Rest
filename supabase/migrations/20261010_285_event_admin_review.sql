-- Upgrade 285: administrator-only event review; no orders or payments are created.
-- Requires trusted server-assigned app_metadata.cafe_role = admin.
create or replace function public.gs_admin_review_event(p_event_id uuid,p_approve boolean,p_note text default null)
returns text language plpgsql security definer set search_path='' as $$
declare e public.gs_event_reservations%rowtype; v_status text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'cafe_role','') <> 'admin' then
  raise exception 'Admin permission required' using errcode='42501'; end if;
 if p_event_id is null or char_length(coalesce(p_note,''))>1000 then raise exception 'Invalid input'; end if;
 select * into e from public.gs_event_reservations where id=p_event_id for update;
 if not found then raise exception 'Event not found'; end if;
 if e.status<>'pending_admin' then raise exception 'Event not pending'; end if;
 if p_approve and e.event_start<=now() then raise exception 'Event already started'; end if;
 if p_approve and e.requested_table_id is not null then
  perform 1 from public.gs_reservable_tables where id=e.requested_table_id and enabled for update;
  if not found then raise exception 'Table disabled'; end if;
  if exists(select 1 from public.gs_public_reservation_requests r
   where r.assigned_table_id=e.requested_table_id and r.status='approved'
   and r.requested_at<e.event_end
   and r.requested_at+make_interval(mins=>r.duration_minutes)>e.event_start)
   or exists(select 1 from public.gs_event_reservations x
   where x.id<>e.id and x.requested_table_id=e.requested_table_id and x.status='approved'
   and x.event_start<e.event_end and x.event_end>e.event_start)
  then raise exception 'Conflicting approved reservation'; end if;
 end if;
 v_status:=case when p_approve then 'approved' else 'rejected' end;
 update public.gs_event_reservations set status=v_status,reviewed_by=auth.uid(),
 reviewed_at=now(),review_note=nullif(trim(coalesce(p_note,'')),''),updated_at=now() where id=e.id;
 insert into public.gs_event_review_audit(event_id,old_status,new_status,actor,note)
 values(e.id,e.status,v_status,auth.uid(),p_note);
 return v_status;
end $$;
revoke all on function public.gs_admin_review_event(uuid,boolean,text) from public,anon;
grant execute on function public.gs_admin_review_event(uuid,boolean,text) to authenticated;
