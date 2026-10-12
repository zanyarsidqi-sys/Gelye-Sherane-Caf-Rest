-- Upgrade 117: close the order-insertion race against cash-only checkout.
-- All newly linked orders serialize on the visit row locked by checkout.
create or replace function public.gs_guard_order_visit_checkout_race()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_status text;v_table_id bigint;v_occupied boolean;
begin
 if new.table_visit_id is null then return new; end if;
 if TG_OP='UPDATE' and new.table_visit_id is not distinct from old.table_visit_id
   then return new; end if;
 -- Row lock is essential: checkout locks the same visit until committed.
 select status,table_id into v_status,v_table_id
 from public.gs_table_visits where id=new.table_visit_id for update;
 if not found or v_status not in ('active','cleaning') then
  raise exception 'Cannot attach order to a closed or missing table visit';
 end if;
 select occupied into v_occupied from public.gs_cafe_tables where id=v_table_id;
 if v_occupied is distinct from true then
  raise exception 'Cannot attach order to a table that is not occupied';
 end if;
 return new;
end; $$;
revoke all on function public.gs_guard_order_visit_checkout_race()
 from public,anon,authenticated;
drop trigger if exists gs_order_visit_checkout_race on public.gs_orders;
create trigger gs_order_visit_checkout_race
 before insert or update of table_visit_id on public.gs_orders
 for each row execute function public.gs_guard_order_visit_checkout_race();

-- Critical invariant: orders may not be moved away from a visit that is
-- currently closing, even by an otherwise authorized staff member.
-- New visit association is locked before checkout can validate its orders.
