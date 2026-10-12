-- Upgrade 461: permission-controlled authorization-specific historical hold diagnostics.
-- Does not expose customer dispute details or permit consent / credit debit.
create or replace function public.gs_staff_credit_authorization_request_hold_check(p_request_id uuid)
returns table(blocked boolean, hold_count bigint, explanation text)
language plpgsql security definer set search_path='' as $$
declare v_account_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 select q.account_id into v_account_id
 from public.gs_credit_customer_authorization_requests q where q.id=p_request_id;
 if v_account_id is null then raise exception 'Authorization request not found'; end if;
 return query select x.blocked,x.hold_count,x.explanation
 from public.gs_staff_credit_authorization_identity_hold_check(v_account_id) x;
end $$;
revoke all on function public.gs_staff_credit_authorization_request_hold_check(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_request_hold_check(uuid) to authenticated;
