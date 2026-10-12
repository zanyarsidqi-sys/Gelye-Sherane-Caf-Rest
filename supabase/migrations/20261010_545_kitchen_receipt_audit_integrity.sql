-- Upgrade 545: receipt and audit must agree atomically; never silently swallow a missing audit record.
create or replace function public.gs_acknowledge_table_replacement_kitchen_revision(p_dispatch_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_dispatch public.gs_order_revision_dispatch%rowtype;
        v_auditor uuid;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required';
 end if;
 select d.* into v_dispatch from public.gs_order_revision_dispatch d
 join public.gs_order_revision_events e on e.id=d.revision_id
 where d.id=p_dispatch_id and d.destination_type='kitchen_revision'
 and e.change_type='price_adjustment'
 and e.before_snapshot ? 'product_id' and e.after_snapshot ? 'product_id'
 and e.before_snapshot->>'product_id' is distinct from e.after_snapshot->>'product_id'
 for update of d;
 if not found then raise exception 'Replacement kitchen revision not found'; end if;
 if v_dispatch.status='acknowledged' then
  select a.acknowledged_by into v_auditor
  from public.gs_kitchen_revision_acknowledgement_audit a
  where a.dispatch_id=p_dispatch_id;
  if v_auditor is null then
   raise exception 'Acknowledged revision is missing its receipt audit; contact administrator';
  end if;
  return jsonb_build_object('dispatch_id',p_dispatch_id,'status','acknowledged',
    'already_acknowledged',true,'acknowledged_by',v_auditor);
 end if;
 if v_dispatch.status not in ('pending','sent','claimed') then
  raise exception 'Revision is not acknowledgeable';
 end if;
 -- Existing conflicting audit means inconsistent state: abort instead of masking it.
 if exists(select 1 from public.gs_kitchen_revision_acknowledgement_audit a
           where a.dispatch_id=p_dispatch_id) then
  raise exception 'Receipt audit exists but dispatch is not acknowledged; contact administrator';
 end if;
 insert into public.gs_kitchen_revision_acknowledgement_audit(dispatch_id,acknowledged_by)
 values(p_dispatch_id,auth.uid());
 update public.gs_order_revision_dispatch
 set status='acknowledged',acknowledged_at=now()
 where id=p_dispatch_id;
 return jsonb_build_object('dispatch_id',p_dispatch_id,'status','acknowledged',
   'already_acknowledged',false,'acknowledged_by',auth.uid());
end $$;
revoke all on function public.gs_acknowledge_table_replacement_kitchen_revision(uuid) from public,anon;
grant execute on function public.gs_acknowledge_table_replacement_kitchen_revision(uuid) to authenticated;
