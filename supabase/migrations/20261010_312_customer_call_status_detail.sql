-- Upgrade 312: customer can see request detail for their authorized visit only.
-- Return a boolean assigned flag, never employee UUID or private staff details.
create or replace function public.gs_customer_call_status(p_session_token uuid,p_call_id uuid)
returns table(status text,call_type text,requested_at timestamptz,
 accepted_at timestamptz,completed_at timestamptz,employee_assigned boolean)
language sql stable security definer set search_path='' as $$
 select c.status,c.call_type,c.requested_at,c.accepted_at,c.completed_at,
        c.assigned_employee is not null
 from public.gs_customer_staff_calls c
 join public.gs_customer_visit_sessions s on s.table_id=c.table_id and s.visit_id=c.visit_id
 join public.gs_cafe_tables t on t.id=s.table_id
 join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id
 where s.session_token=p_session_token and s.revoked_at is null and s.expires_at>now()
 and t.occupied and v.status='open' and c.id=p_call_id;
$$;
revoke all on function public.gs_customer_call_status(uuid,uuid) from public;
grant execute on function public.gs_customer_call_status(uuid,uuid) to anon,authenticated;
