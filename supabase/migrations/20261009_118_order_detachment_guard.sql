-- Upgrade 118: prevent detaching orders to evade checkout's attestation count.
-- Supersedes the earlier association guard from Upgrade 117.
create or replace function public.gs_guard_order_visit_checkout_race()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_status text;v_table_id bigint;v_occupied boolean;
 v_old_visit bigint;v_new_visit bigint;v_lock_visit bigint;
begin
 v_old_visit:=case when TG_OP='UPDATE' then old.table_visit_id else null end;
 v_new_visit:=new.table_visit_id;
 if TG_OP='UPDATE' and v_old_visit is not distinct from v_new_visit then
  return new;
 end if;
 -- Lock BOTH visits in stable ID order. A visit release takes this row lock
 -- before it counts orders; moving an order cannot race around that count.
 for v_lock_visit in
  select distinct x from unnest(array[v_old_visit,v_new_visit]) as x
   where x is not null order by x
 loop
  perform 1 from public.gs_table_visits where id=v_lock_visit for update;
  if not found then raise exception 'Order visit does not exist';end if;
 end loop;
 if v_old_visit is not null then
  select status into v_status from public.gs_table_visits where id=v_old_visit;
  if v_status not in ('active','cleaning') then
   raise exception 'Cannot detach order from closed table visit';
  end if;
  -- Finance-attested orders are bound to the exact visit and may not be moved.
  if exists(select 1 from public.gs_cash_only_settlement_attestations
    where order_id=old.id) then
   raise exception 'Cannot move an independently settled order';
  end if;
 end if;
 if v_new_visit is not null then
  select status,table_id into v_status,v_table_id
   from public.gs_table_visits where id=v_new_visit;
  if v_status not in ('active','cleaning') then
   raise exception 'Cannot attach order to closed table visit';
  end if;
  select occupied into v_occupied from public.gs_cafe_tables where id=v_table_id;
  if v_occupied is distinct from true then
   raise exception 'Cannot attach order to unoccupied table';
  end if;
 end if;
 return new;
end; $$;
-- Trigger from Upgrade 117 remains installed, now executing the replacement.
