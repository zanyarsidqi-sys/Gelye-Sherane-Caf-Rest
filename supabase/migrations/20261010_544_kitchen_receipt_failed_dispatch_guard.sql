-- Upgrade 544: failed kitchen dispatches require audited retry before manual receipt.
-- Replaces existing RPC in place; retains permission, row locking and audit semantics.
create or replace function public.gs_acknowledge_table_replacement_kitchen_revision(p_dispatch_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_dispatch public.gs_order_revision_dispatch%rowtype;
        v_order_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required'; end if;
 select d.* into v_dispatch from public.gs_order_revision_dispatch d
 join public.gs_order_revision_events e on e.id=d.revision_id
 where d.id=p_dispatch_id and d.destination_type='kitchen_revision'
 and e.change_type='price_adjustment'
 and e.before_snapshot ? 'product_id' and e.after_snapshot ? 'product_id'
 and e.before_snapshot->>'product_id' is distinct from e.after_snapshot->>'product_id'
 for update of d;
 if not found then raise exception 'Replacement kitchen revision not found'; end if;
 if v_dispatch.status='acknowledged' then
  return jsonb_build_object('dispatch_id',p_dispatch_id,'status','acknowledged','already_acknowledged',true); end if;
 if v_dispatch.status not in ('pending','sent','claimed') then
  raise exception 'Revision is not acknowledgeable'; end if;
 update public.gs_order_revision_dispatch set status='acknowledged',acknowledged_at=now()
 where id=p_dispatch_id;
 insert into public.gs_kitchen_revision_acknowledgement_audit(dispatch_id,acknowledged_by)
 values(p_dispatch_id,auth.uid()) on conflict(dispatch_id) do nothing;
 return jsonb_build_object('dispatch_id',p_dispatch_id,'status','acknowledged','already_acknowledged',false);
end $$;
revoke all on function public.gs_acknowledge_table_replacement_kitchen_revision(uuid) from public,anon;
grant execute on function public.gs_acknowledge_table_replacement_kitchen_revision(uuid) to authenticated;
