-- Upgrade 1202: approved corrections become station-scoped, immutable revision notices.
-- Original dispatched tickets are NEVER deleted or silently edited: physical
-- preparation/printing may already have occurred. This is not a printer ACK.
create table if not exists public.gs_cafe_correction_station_revisions (
 id bigint generated always as identity primary key,
 correction_id bigint not null references public.gs_order_item_corrections(id) on delete restrict,
 order_id bigint not null references public.gs_orders(id) on delete restrict,
 station_key text not null references public.gs_cafe_preparation_stations(station_key),
 revision_kind text not null check(revision_kind in ('stop_wrong_item','prepare_replacement')),
 order_item_id bigint not null references public.gs_order_items(id) on delete restrict,
 quantity integer not null check(quantity>0),
 original_ticket_id bigint references public.gs_cafe_order_station_tickets(id),
 state text not null default 'pending' check(state in ('pending','acknowledged','unable_to_stop')),
 created_at timestamptz not null default now(),
 acknowledged_at timestamptz,
 acknowledged_by uuid references auth.users(id),
 unique(correction_id,revision_kind)
);
create index if not exists gs_correction_revision_station_pending
 on public.gs_cafe_correction_station_revisions(station_key,created_at) where state='pending';
alter table public.gs_cafe_correction_station_revisions enable row level security;
revoke all on public.gs_cafe_correction_station_revisions from public,anon,authenticated;

-- Explicit manager operation after approval/replacement; idempotent under locks.
-- If the replacement has not been added, create ONLY the stop notice. A later
-- invocation adds the replacement notice exactly once.
create or replace function public.gs_stage_correction_station_revisions(p_correction_id bigint)
returns integer language plpgsql security definer set search_path='' as $$
declare c record; v_station text; v_ticket bigint; v_count integer:=0; v_replacement_station text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
 or not public.gs_can_access('table_orders','can_edit')
 or not public.gs_can_access('kitchen','can_edit') then
   raise exception 'Manager with MFA, Table Orders and Kitchen edit permissions required';
 end if;
 select x.*,o.status as order_status into c
 from public.gs_order_item_corrections x join public.gs_orders o on o.id=x.order_id
 where x.id=p_correction_id for update of x,o;
 if not found or c.decision<>'approved' then raise exception 'Approved correction required'; end if;
 if c.order_status in ('cancelled','served') then raise exception 'Order is terminal'; end if;
 if not exists(select 1 from public.gs_order_items i
               where i.id=c.item_id and i.order_id=c.order_id) then
   raise exception 'Original item/order mismatch'; end if;
 select t.station_key,t.id into v_station,v_ticket
 from public.gs_cafe_order_station_ticket_items ti
 join public.gs_cafe_order_station_tickets t on t.id=ti.ticket_id
 where ti.order_item_id=c.item_id and t.order_id=c.order_id;
 if v_station is null then
   -- An item not dispatched to a station must not receive a false stop notice.
   -- Its approved financial correction is preserved separately.
   if c.replacement_item_id is null then return 0; end if;
 else
   insert into public.gs_cafe_correction_station_revisions
    (correction_id,order_id,station_key,revision_kind,order_item_id,quantity,original_ticket_id)
   values(c.id,c.order_id,v_station,'stop_wrong_item',c.item_id,c.requested_quantity,v_ticket)
   on conflict(correction_id,revision_kind) do nothing;
   if found then v_count:=v_count+1; end if;
 end if;
 if c.replacement_item_id is not null then
   if not exists(select 1 from public.gs_order_items i
     where i.id=c.replacement_item_id and i.order_id=c.order_id
       and i.quantity=c.requested_quantity and i.product_id=c.replacement_product_id) then
     raise exception 'Replacement item identity or quantity mismatch'; end if;
   select s.station_key into v_replacement_station
   from public.gs_order_items i
   join public.gs_cafe_product_preparation m on m.product_id=i.product_id
   join public.gs_cafe_preparation_stations s on s.station_key=m.station_key and s.enabled
   where i.id=c.replacement_item_id;
   if v_replacement_station is null then raise exception 'Replacement requires active station mapping'; end if;
   insert into public.gs_cafe_correction_station_revisions
    (correction_id,order_id,station_key,revision_kind,order_item_id,quantity)
   values(c.id,c.order_id,v_replacement_station,'prepare_replacement',c.replacement_item_id,c.requested_quantity)
   on conflict(correction_id,revision_kind) do nothing;
   if found then v_count:=v_count+1; end if;
 end if;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'kitchen','correction_revision_staged',c.id::text,
 jsonb_build_object('new_notices',v_count,'replacement_item_id',c.replacement_item_id));
 return v_count;
end; $$;
revoke all on function public.gs_stage_correction_station_revisions(bigint) from public,anon;
grant execute on function public.gs_stage_correction_station_revisions(bigint) to authenticated;

create or replace function public.gs_kitchen_correction_revision_queue()
returns table(revision_id bigint,correction_id bigint,order_id bigint,station_key text,
 revision_kind text,order_item_id bigint,product_name text,quantity integer,
 state text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_view') then
   raise exception 'Kitchen view permission required'; end if;
 return query select r.id,r.correction_id,r.order_id,r.station_key,r.revision_kind,
 r.order_item_id,p.name,r.quantity,r.state,r.created_at
 from public.gs_cafe_correction_station_revisions r
 join public.gs_order_items i on i.id=r.order_item_id
 join public.gs_menu_products p on p.id=i.product_id
 order by (r.state='pending') desc,r.created_at desc limit 250;
end; $$;
revoke all on function public.gs_kitchen_correction_revision_queue() from public,anon;
grant execute on function public.gs_kitchen_correction_revision_queue() to authenticated;

create or replace function public.gs_ack_correction_station_revision(p_revision_id bigint,p_unable_to_stop boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare r public.gs_cafe_correction_station_revisions%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
   raise exception 'Kitchen edit permission required'; end if;
 select * into r from public.gs_cafe_correction_station_revisions where id=p_revision_id for update;
 if not found then raise exception 'Revision not found'; end if;
 if r.state<>'pending' then return; end if;
 if p_unable_to_stop and r.revision_kind<>'stop_wrong_item' then
   raise exception 'Unable-to-stop applies only to incorrect preparation'; end if;
 update public.gs_cafe_correction_station_revisions set
 state=case when p_unable_to_stop then 'unable_to_stop' else 'acknowledged' end,
 acknowledged_at=transaction_timestamp(),acknowledged_by=auth.uid()
 where id=p_revision_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'kitchen','correction_revision_ack',p_revision_id::text,
 jsonb_build_object('unable_to_stop',p_unable_to_stop,'station_key',r.station_key));
end; $$;
revoke all on function public.gs_ack_correction_station_revision(bigint,boolean) from public,anon;
grant execute on function public.gs_ack_correction_station_revision(bigint,boolean) to authenticated;
