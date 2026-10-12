-- Upgrade 540: supervised retry of failed kitchen replacement revision queue entries.
-- Requeue is not proof of delivery; an external worker must process pending entries.
create table if not exists public.gs_kitchen_revision_retry_audit (
 id bigint generated always as identity primary key,
 dispatch_id uuid not null references public.gs_order_revision_dispatch(id) on delete restrict,
 retried_by uuid not null,
 retried_at timestamptz not null default now(),
 previous_attempts integer not null,
 reason text not null check(length(btrim(reason)) between 5 and 250)
);
alter table public.gs_kitchen_revision_retry_audit enable row level security;
revoke all on public.gs_kitchen_revision_retry_audit from public,anon,authenticated;

create or replace function public.gs_retry_failed_kitchen_replacement_revision(
 p_dispatch_id uuid, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_dispatch public.gs_order_revision_dispatch%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('kitchen','can_edit') then
  raise exception 'Kitchen edit permission required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 5 and 250 then
  raise exception 'Retry reason must be 5-250 characters'; end if;
 select d.* into v_dispatch from public.gs_order_revision_dispatch d
 join public.gs_order_revision_events e on e.id=d.revision_id
 where d.id=p_dispatch_id and d.destination_type='kitchen_revision'
 and e.change_type='price_adjustment'
 and e.before_snapshot ? 'product_id' and e.after_snapshot ? 'product_id'
 and e.before_snapshot->>'product_id' is distinct from e.after_snapshot->>'product_id'
 for update of d;
 if not found then raise exception 'Replacement revision not found'; end if;
 if v_dispatch.status <> 'failed' or v_dispatch.acknowledged_at is not null then
  raise exception 'Only failed, unacknowledged revisions can be retried'; end if;
 insert into public.gs_kitchen_revision_retry_audit(dispatch_id,retried_by,previous_attempts,reason)
 values(p_dispatch_id,auth.uid(),v_dispatch.attempts,btrim(p_reason));
 update public.gs_order_revision_dispatch set status='pending'
 where id=p_dispatch_id;
 return jsonb_build_object('dispatch_id',p_dispatch_id,'status','pending',
  'previous_attempts',v_dispatch.attempts,'delivery_confirmed',false);
end $$;
revoke all on function public.gs_retry_failed_kitchen_replacement_revision(uuid,text) from public,anon;
grant execute on function public.gs_retry_failed_kitchen_replacement_revision(uuid,text) to authenticated;
