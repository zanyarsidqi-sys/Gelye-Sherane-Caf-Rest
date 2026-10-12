-- Upgrade 255: clear table-scoped temporary pricing when an occupied table is released.
-- Existing guarded checkout RPCs remain responsible for proving complete settlement.
-- This trigger DOES NOT authorize checkout or release a table.
create or replace function public.gs_reset_table_pricing_on_release()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_old jsonb; v_new jsonb; v_discount_id bigint;
begin
 if old.occupied = true and new.occupied = false then
   -- The next visit must always start in Normal Mode.
   new.tourism_mode := false;
   -- Keep a historical record of temporary discount configuration changes.
   select id, to_jsonb(d) into v_discount_id, v_old
     from public.gs_cafe_discount_modes d
     where d.scope='table' and d.scope_reference=old.table_number::text
     for update;
   if v_discount_id is not null then
     update public.gs_cafe_discount_modes as d
       set is_active=false, base_mode='normal',
           updated_at=now(), updated_by=coalesce(auth.uid(), old.updated_by, d.updated_by)
       where id=v_discount_id
       returning to_jsonb(d) into v_new;
     -- Audit schema requires a real actor; never manufacture a user UUID.
     if auth.uid() is not null then
       insert into public.gs_cafe_discount_mode_audit
         (discount_mode_id, actor_id, old_config, new_config)
       values (v_discount_id, auth.uid(), v_old, v_new);
     end if;
   end if;
 end if;
 return new;
end; $$;
revoke all on function public.gs_reset_table_pricing_on_release() from public,anon,authenticated;
drop trigger if exists gs_table_checkout_mode_reset on public.gs_cafe_tables;
create trigger gs_table_checkout_mode_reset
before update of occupied on public.gs_cafe_tables
for each row execute function public.gs_reset_table_pricing_on_release();
-- IMPORTANT: Owner Mode is represented in discount configuration in this
-- schema; any future standalone owner-mode column must be added to this reset.
-- No historic order-item snapshots, invoices, or payment ledgers are modified.
