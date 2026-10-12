-- Upgrade 417: read-only revocation audit and append-only enforcement.
create or replace function public.gs_staff_list_credit_link_revocations(p_registry_id uuid)
returns table(audit_id uuid, registry_id uuid, account_id uuid,
 previous_status text, reason text, revoked_by uuid, revoked_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select a.id,a.registry_id,a.account_id,a.previous_status,
 a.reason,a.revoked_by,a.revoked_at
 from public.gs_credit_link_revocation_audit a
 where p_registry_id is null or a.registry_id=p_registry_id
 order by a.revoked_at desc,a.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_link_revocations(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_link_revocations(uuid) to authenticated;

create or replace function public.gs_credit_reject_audit_mutation()
returns trigger language plpgsql set search_path='' as $$
begin
 raise exception 'Credit link revocation audit records cannot be updated or deleted';
end $$;
drop trigger if exists gs_credit_revocation_audit_immutable on public.gs_credit_link_revocation_audit;
create trigger gs_credit_revocation_audit_immutable
before update or delete on public.gs_credit_link_revocation_audit
for each row execute function public.gs_credit_reject_audit_mutation();
