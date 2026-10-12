-- Upgrade 549: permission-gated exception case intake. No automatic receipt or financial mutations.
create table if not exists public.gs_kitchen_revision_exception_cases (
 id uuid primary key default gen_random_uuid(),
 dispatch_id uuid not null references public.gs_order_revision_dispatch(id) on delete restrict,
 reconciliation_state text not null,
 investigation_note text not null check (char_length(btrim(investigation_note)) between 10 and 1000),
 opened_by uuid not null references auth.users(id),
 opened_at timestamptz not null default now(),
 status text not null default 'open' check (status in ('open','closed')),
 closed_by uuid references auth.users(id),
 closed_at timestamptz,
 resolution_note text,
 constraint gs_exception_close_complete check ((status='open' and closed_at is null and closed_by is null and resolution_note is null) or (status='closed' and closed_at is not null and closed_by is not null and char_length(btrim(resolution_note)) >= 10))
);
create unique index if not exists gs_kitchen_revision_one_open_exception
 on public.gs_kitchen_revision_exception_cases(dispatch_id) where status='open';
create index if not exists gs_kitchen_revision_exception_dispatch_idx on public.gs_kitchen_revision_exception_cases(dispatch_id,opened_at desc);
alter table public.gs_kitchen_revision_exception_cases enable row level security;
revoke all on public.gs_kitchen_revision_exception_cases from public,anon,authenticated;

create or replace function public.gs_staff_open_kitchen_revision_exception(p_order_id bigint,p_dispatch_id uuid,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_state text; v_case uuid;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_edit') and public.gs_can_access('kitchen','can_view')) then
  raise exception 'Table order editing and kitchen viewing permissions required';
 end if;
 if char_length(btrim(coalesce(p_note,''))) not between 10 and 1000 then
  raise exception 'Investigation note must contain 10 to 1000 characters';
 end if;
 -- Lock dispatch to serialize case intake with other dispatch updates.
 perform 1 from public.gs_order_revision_dispatch d where d.id=p_dispatch_id for update;
 if not found then raise exception 'Dispatch not found'; end if;
 select r.reconciliation_state into v_state
 from public.gs_staff_kitchen_revision_reconciliation(p_order_id) r
 where r.dispatch_id=p_dispatch_id;
 if v_state is null then raise exception 'Dispatch does not belong to this table order or is outside reconciliation scope'; end if;
 if v_state in ('acknowledged_consistent','awaiting_kitchen_receipt','failed_requires_recovery') then
  raise exception 'No receipt audit exception detected';
 end if;
 select c.id into v_case from public.gs_kitchen_revision_exception_cases c
 where c.dispatch_id=p_dispatch_id and c.status='open';
 if v_case is not null then return v_case; end if;
 insert into public.gs_kitchen_revision_exception_cases(dispatch_id,reconciliation_state,investigation_note,opened_by)
 values(p_dispatch_id,v_state,btrim(p_note),auth.uid()) returning id into v_case;
 return v_case;
end $$;
revoke all on function public.gs_staff_open_kitchen_revision_exception(bigint,uuid,text) from public,anon;
grant execute on function public.gs_staff_open_kitchen_revision_exception(bigint,uuid,text) to authenticated;

create or replace function public.gs_staff_kitchen_revision_exception_cases(p_order_id bigint)
returns table(case_id uuid,dispatch_id uuid,reconciliation_state text,investigation_note text,opened_by uuid,opened_at timestamptz,status text)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view') and public.gs_can_access('kitchen','can_view')) then
  raise exception 'Table orders and kitchen view permissions required';
 end if;
 return query select c.id,c.dispatch_id,c.reconciliation_state,c.investigation_note,c.opened_by,c.opened_at,c.status
 from public.gs_kitchen_revision_exception_cases c
 join public.gs_order_revision_dispatch d on d.id=c.dispatch_id
 join public.gs_order_revision_events e on e.id=d.revision_id
 join public.gs_orders o on o.id=e.order_id
 where o.id=p_order_id and o.is_motel=false
 order by c.opened_at desc limit 250;
end $$;
revoke all on function public.gs_staff_kitchen_revision_exception_cases(bigint) from public,anon;
grant execute on function public.gs_staff_kitchen_revision_exception_cases(bigint) to authenticated;
