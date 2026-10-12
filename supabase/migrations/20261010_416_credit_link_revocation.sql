-- Upgrade 416: controlled revocation of an unverified barcode-account link.
-- Revocation never approves identity or authorizes a financial transaction.
create table if not exists public.gs_credit_link_revocation_audit (
 id uuid primary key default extensions.gen_random_uuid(),
 registry_id uuid not null references public.gs_motel_credit_barcode_registry(id),
 account_id uuid not null references public.gs_credit_accounts(id),
 previous_status text not null,
 reason text not null check(length(btrim(reason)) between 10 and 1000),
 revoked_by uuid not null references auth.users(id),
 revoked_at timestamptz not null default now()
);
alter table public.gs_credit_link_revocation_audit enable row level security;
revoke all on public.gs_credit_link_revocation_audit from public,anon,authenticated;
create or replace function public.gs_staff_revoke_pending_credit_link(
 p_registry_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_link public.gs_credit_account_registry_links%rowtype; v_audit uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 10 and 1000
 then raise exception 'Reason must contain 10-1000 characters'; end if;
 select * into v_link from public.gs_credit_account_registry_links
 where registry_id=p_registry_id for update;
 if not found or v_link.link_status<>'pending'
 then raise exception 'Only pending barcode-account links can be revoked'; end if;
 -- Cancel outstanding evidence review requests for this link, preserving audit rows.
 update public.gs_credit_identity_review_requests
 set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),
     review_note='Link revoked: ' || btrim(p_reason)
 where registry_id=p_registry_id and status='pending';
 update public.gs_credit_account_registry_links set link_status='revoked'
 where registry_id=p_registry_id;
 insert into public.gs_credit_link_revocation_audit
 (registry_id,account_id,previous_status,reason,revoked_by)
 values(v_link.registry_id,v_link.account_id,v_link.link_status,btrim(p_reason),auth.uid())
 returning id into v_audit;
 return v_audit;
end $$;
revoke all on function public.gs_staff_revoke_pending_credit_link(uuid,text) from public,anon;
grant execute on function public.gs_staff_revoke_pending_credit_link(uuid,text) to authenticated;
