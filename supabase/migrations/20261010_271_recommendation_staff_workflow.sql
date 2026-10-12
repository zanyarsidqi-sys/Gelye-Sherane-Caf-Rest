-- Upgrade 271: staff workflow for product recommendations.
-- Customer anonymous submission remains disabled until visit-scoped authorization.
alter table public.gs_product_recommendations
  add column if not exists employee_note text,
  add column if not exists linked_menu_product_id bigint,
  add column if not exists updated_by uuid,
  add column if not exists updated_at timestamptz,
  add column if not exists completed_at timestamptz;
-- Replace the draft status constraint while retaining old statuses.
alter table public.gs_product_recommendations drop constraint if exists gs_product_recommendations_status_check;
alter table public.gs_product_recommendations add constraint gs_product_recommendations_status_check
  check (status in ('pending','in_review','approved','added_to_menu','done','rejected'));
alter table public.gs_product_recommendations add constraint gs_recommendation_note_length
  check (employee_note is null or char_length(employee_note)<=1000);
create table if not exists public.gs_product_recommendation_audit (
 id bigint generated always as identity primary key,
 recommendation_id uuid not null references public.gs_product_recommendations(id),
 old_status text not null, new_status text not null,
 old_note text, new_note text,
 old_menu_product_id bigint, new_menu_product_id bigint,
 changed_by uuid not null, changed_at timestamptz not null default now()
);
alter table public.gs_product_recommendation_audit enable row level security;
revoke all on public.gs_product_recommendation_audit from public,anon,authenticated;

create or replace function public.gs_staff_recommendation_list()
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Not authorized';
 end if;
 return query select to_jsonb(r) from public.gs_product_recommendations r
 order by r.created_at desc limit 200;
end $$;

create or replace function public.gs_staff_update_recommendation(
 p_id uuid, p_status text, p_note text default null,
 p_menu_product_id bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_old public.gs_product_recommendations%rowtype;
        v_result public.gs_product_recommendations%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_edit') then
  raise exception 'Not authorized to update recommendations';
 end if;
 if p_status not in ('pending','in_review','approved','added_to_menu','done','rejected') then
  raise exception 'Invalid recommendation status';
 end if;
 if length(coalesce(p_note,''))>1000 then raise exception 'Note too long'; end if;
 select * into v_old from public.gs_product_recommendations where id=p_id for update;
 if not found then raise exception 'Recommendation not found'; end if;
 if p_status in ('added_to_menu','done') and v_old.type='Suggest new product' then
  if p_menu_product_id is null or not exists
     (select 1 from public.gs_menu_products m where m.id=p_menu_product_id) then
    raise exception 'Link an existing menu product before marking a new-product request added or done';
  end if;
  if not public.gs_can_access('menu','can_edit') then
    raise exception 'Menu editing permission required to confirm a new product';
  end if;
 end if;
 update public.gs_product_recommendations set
  status=p_status, employee_note=p_note,
  linked_menu_product_id=p_menu_product_id,
  updated_by=auth.uid(), updated_at=now(),
  completed_at=case when p_status='done' then now() else null end
 where id=p_id returning * into v_result;
 insert into public.gs_product_recommendation_audit
 (recommendation_id,old_status,new_status,old_note,new_note,
  old_menu_product_id,new_menu_product_id,changed_by)
 values(p_id,v_old.status,p_status,v_old.employee_note,p_note,
        v_old.linked_menu_product_id,p_menu_product_id,auth.uid());
 return to_jsonb(v_result);
end $$;
revoke all on function public.gs_staff_recommendation_list() from public,anon;
revoke all on function public.gs_staff_update_recommendation(uuid,text,text,bigint) from public,anon;
grant execute on function public.gs_staff_recommendation_list() to authenticated;
grant execute on function public.gs_staff_update_recommendation(uuid,text,text,bigint) to authenticated;
