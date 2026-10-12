-- Upgrade 551: immutable closure history and safe re-investigation.
-- A reopened investigation is a NEW case linked to the closed case.
alter table public.gs_kitchen_revision_exception_cases
 add column if not exists reopened_from_case_id uuid references public.gs_kitchen_revision_exception_cases(id) on delete restrict;
create index if not exists gs_kitchen_exception_reopen_chain_idx
 on public.gs_kitchen_revision_exception_cases(reopened_from_case_id);

create or replace function public.gs_staff_reopen_kitchen_revision_exception(
 p_order_id bigint, p_closed_case_id uuid, p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_old public.gs_kitchen_revision_exception_cases%rowtype;
        v_state text; v_new uuid; v_existing uuid;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_edit') and public.gs_can_access('kitchen','can_edit')) then
  raise exception 'Table Orders and Kitchen editing permissions required';
 end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 10 and 1000 then
  raise exception 'Reinvestigation reason must contain 10 to 1000 characters';
 end if;
 -- Serialize competing reopen requests for the same dispatch.
 select c.* into v_old from public.gs_kitchen_revision_exception_cases c
 join public.gs_order_revision_dispatch d on d.id=c.dispatch_id
 join public.gs_order_revision_events e on e.id=d.revision_id
 join public.gs_orders o on o.id=e.order_id
 where c.id=p_closed_case_id and o.id=p_order_id and o.is_motel=false;
 if not found then raise exception 'Case not found for table order'; end if;
 perform 1 from public.gs_order_revision_dispatch d where d.id=v_old.dispatch_id for update;
 select c.* into v_old from public.gs_kitchen_revision_exception_cases c
 where c.id=p_closed_case_id for update;
 if v_old.status <> 'closed' then raise exception 'Only closed cases can be reinvestigated'; end if;
 select r.reconciliation_state into v_state
 from public.gs_staff_kitchen_revision_reconciliation(p_order_id) r
 where r.dispatch_id=v_old.dispatch_id;
 if v_state is null then raise exception 'Revision is outside reconciliation scope'; end if;
 if v_state in ('acknowledged_consistent','awaiting_kitchen_receipt','failed_requires_recovery') then
  raise exception 'Reinvestigation requires a current receipt audit inconsistency';
 end if;
 select c.id into v_existing from public.gs_kitchen_revision_exception_cases c
 where c.dispatch_id=v_old.dispatch_id and c.status='open';
 if v_existing is not null then raise exception 'An open investigation already exists'; end if;
 insert into public.gs_kitchen_revision_exception_cases
 (dispatch_id,reconciliation_state,investigation_note,opened_by,reopened_from_case_id)
 values (v_old.dispatch_id,v_state,btrim(p_reason),auth.uid(),v_old.id)
 returning id into v_new;
 return v_new;
end $$;
revoke all on function public.gs_staff_reopen_kitchen_revision_exception(bigint,uuid,text) from public,anon;
grant execute on function public.gs_staff_reopen_kitchen_revision_exception(bigint,uuid,text) to authenticated;

-- PostgreSQL return shape changes require DROP before CREATE.
drop function if exists public.gs_staff_kitchen_revision_exception_cases(bigint);
create function public.gs_staff_kitchen_revision_exception_cases(p_order_id bigint)
returns table(case_id uuid,dispatch_id uuid,reconciliation_state text,investigation_note text,opened_by uuid,opened_at timestamptz,status text,closed_by uuid,closed_at timestamptz,resolution_note text,reopened_from_case_id uuid)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view') and public.gs_can_access('kitchen','can_view')) then
  raise exception 'Table Orders and Kitchen viewing permissions required';
 end if;
 return query select c.id,c.dispatch_id,c.reconciliation_state,c.investigation_note,c.opened_by,c.opened_at,c.status,c.closed_by,c.closed_at,c.resolution_note,c.reopened_from_case_id
 from public.gs_kitchen_revision_exception_cases c
 join public.gs_order_revision_dispatch d on d.id=c.dispatch_id
 join public.gs_order_revision_events e on e.id=d.revision_id
 join public.gs_orders o on o.id=e.order_id
 where o.id=p_order_id and o.is_motel=false order by c.opened_at desc limit 250;
end $$;
revoke all on function public.gs_staff_kitchen_revision_exception_cases(bigint) from public,anon;
grant execute on function public.gs_staff_kitchen_revision_exception_cases(bigint) to authenticated;
