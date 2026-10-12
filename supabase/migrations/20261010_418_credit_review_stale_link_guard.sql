-- Upgrade 418: reject stale identity review decisions after link revocation.
-- Lock link first, consistent with the revocation RPC's link-first lock order.
create or replace function public.gs_staff_decide_credit_identity_review(
 p_review_id uuid,p_accept_evidence boolean,p_note text)
returns text language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
 v_link public.gs_credit_account_registry_links%rowtype;
 v_account public.gs_credit_accounts%rowtype;
 v_review_registry uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_accept_evidence is null or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Decision and review note required'; end if;
 -- Discover immutable registry identifier, then acquire link lock BEFORE review lock.
 select registry_id into v_review_registry from public.gs_credit_identity_review_requests where id=p_review_id;
 if not found then raise exception 'Review not found'; end if;
 select * into v_link from public.gs_credit_account_registry_links
 where registry_id=v_review_registry for update;
 if not found or v_link.link_status<>'pending'
 then raise exception 'Link is not pending; stale review cannot be accepted'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=p_review_id for update;
 if not found or v.status<>'pending' or v.registry_id<>v_link.registry_id
 or v.account_id<>v_link.account_id
 then raise exception 'Review is stale or no longer pending'; end if;
 select * into v_account from public.gs_credit_accounts where id=v_link.account_id;
 if not found or v_account.account_status<>'pending'
 then raise exception 'Credit account is no longer pending'; end if;
 if v.requested_by=auth.uid() then raise exception 'Second independent employee required'; end if;
 update public.gs_credit_identity_review_requests
 set status=case when p_accept_evidence then 'reviewed' else 'rejected' end,
 reviewed_by=auth.uid(), reviewed_at=now(), review_note=btrim(p_note)
 where id=v.id;
 -- Evidence review never verifies identity or activates the link/account.
 return case when p_accept_evidence then 'reviewed_not_verified' else 'rejected' end;
end $$;
revoke all on function public.gs_staff_decide_credit_identity_review(uuid,boolean,text) from public,anon;
grant execute on function public.gs_staff_decide_credit_identity_review(uuid,boolean,text) to authenticated;
