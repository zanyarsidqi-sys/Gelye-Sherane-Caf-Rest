-- Upgrade 315: separate queue visibility from permission to change call status.
-- Viewing customer calls requires can_view; claiming/completing requires can_edit.
create or replace function public.gs_staff_can_manage_customer_calls()
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and coalesce(public.gs_can_access('table_orders','can_edit'),false);
$$;
revoke all on function public.gs_staff_can_manage_customer_calls() from public,anon;
grant execute on function public.gs_staff_can_manage_customer_calls() to authenticated;

create or replace function public.gs_staff_update_customer_call(p_id uuid,p_status text)
returns boolean language plpgsql security definer set search_path='' as $$
declare c public.gs_customer_staff_calls%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('table_orders','can_edit'),false) then
  raise exception 'Editing customer requests requires Table Orders edit permission' using errcode='42501';
 end if;
 if p_id is null or p_status is null then raise exception 'Missing call or status'; end if;
 select * into c from public.gs_customer_staff_calls where id=p_id for update;
 if not found then raise exception 'Call not found'; end if;
 if not ((c.status='waiting' and p_status in ('accepted','cancelled'))
  or (c.status='accepted' and p_status in ('on_way','completed'))
  or (c.status='on_way' and p_status='completed')) then
  raise exception 'Invalid call transition'; end if;
 if c.assigned_employee is not null and c.assigned_employee<>auth.uid() then
  raise exception 'Assigned to another employee'; end if;
 update public.gs_customer_staff_calls set status=p_status,
 assigned_employee=case when p_status='cancelled' then assigned_employee else auth.uid() end,
 accepted_at=case when p_status='accepted' then now() else accepted_at end,
 completed_at=case when p_status in ('completed','cancelled') then now() else completed_at end,
 updated_at=now() where id=p_id;
 insert into public.gs_customer_call_audit(call_id,employee_id,from_status,to_status)
 values(p_id,auth.uid(),c.status,p_status);
 return true;
end $$;
revoke all on function public.gs_staff_update_customer_call(uuid,text) from public,anon;
grant execute on function public.gs_staff_update_customer_call(uuid,text) to authenticated;
