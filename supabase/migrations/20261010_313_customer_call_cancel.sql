-- Upgrade 313: customers can cancel their own waiting assistance requests.
-- Lock the visit session and call row to serialize cancellation with staff acceptance.
create or replace function public.gs_customer_cancel_call(
  p_session_token uuid, p_call_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_table_id bigint; v_visit_id bigint; v_call public.gs_customer_staff_calls%rowtype;
begin
  if p_session_token is null or p_call_id is null then
    raise exception 'Missing request or visit token';
  end if;
  select s.table_id, s.visit_id into v_table_id, v_visit_id
  from public.gs_customer_visit_sessions s
  join public.gs_cafe_tables t on t.id=s.table_id
  join public.gs_table_visits v on v.id=s.visit_id and v.table_id=s.table_id
  where s.session_token=p_session_token and s.revoked_at is null
    and s.expires_at>now() and t.occupied and v.status='open'
  for update of s;
  if not found then raise exception 'Active visit authorization required' using errcode='42501'; end if;
  select * into v_call from public.gs_customer_staff_calls c
  where c.id=p_call_id and c.table_id=v_table_id and c.visit_id=v_visit_id
  for update;
  if not found then raise exception 'Request not found' using errcode='42501'; end if;
  if v_call.status <> 'waiting' then
    raise exception 'Only waiting requests can be cancelled';
  end if;
  update public.gs_customer_staff_calls
    set status='cancelled', completed_at=now(), updated_at=now()
  where id=v_call.id;
  return true;
end $$;
revoke all on function public.gs_customer_cancel_call(uuid,uuid) from public;
grant execute on function public.gs_customer_cancel_call(uuid,uuid) to anon,authenticated;
