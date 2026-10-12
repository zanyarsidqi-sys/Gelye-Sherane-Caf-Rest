-- Upgrade 414: two-person evidence review. Not an authoritative identity verification.
create table if not exists public.gs_credit_identity_review_requests (
 id uuid primary key default extensions.gen_random_uuid(),
 registry_id uuid not null references public.gs_credit_account_registry_links(registry_id),
 account_id uuid not null references public.gs_credit_accounts(id),
 evidence_reference text not null check(length(btrim(evidence_reference)) between 8 and 250),
 requester_note text not null check(length(btrim(requester_note)) between 10 and 1000),
 status text not null default 'pending' check(status in ('pending','reviewed','rejected')),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now(),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_note text,
 check ((status='pending' and reviewed_by is null and reviewed_at is null) or
        (status<>'pending' and reviewed_by is not null and reviewed_at is not null and
         length(btrim(review_note)) between 10 and 1000))
);
create unique index if not exists gs_credit_identity_one_pending_per_link
 on public.gs_credit_identity_review_requests(registry_id) where status='pending';
alter table public.gs_credit_identity_review_requests enable row level security;
revoke all on public.gs_credit_identity_review_requests from public,anon,authenticated;

create or replace function public.gs_staff_request_credit_identity_review(
 p_registry_id uuid,p_evidence_reference text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_account uuid; v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_evidence_reference is null or length(btrim(p_evidence_reference)) not between 8 and 250
 or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Evidence reference and note are required'; end if;
 select l.account_id into v_account from public.gs_credit_account_registry_links l
 join public.gs_credit_accounts a on a.id=l.account_id
 where l.registry_id=p_registry_id and l.link_status='pending' and a.account_status='pending'
 for update of l;
 if not found then raise exception 'Pending barcode-account link required'; end if;
 insert into public.gs_credit_identity_review_requests
 (registry_id,account_id,evidence_reference,requester_note,requested_by)
 values(p_registry_id,v_account,btrim(p_evidence_reference),btrim(p_note),auth.uid())
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_request_credit_identity_review(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_request_credit_identity_review(uuid,text,text) to authenticated;

create or replace function public.gs_staff_decide_credit_identity_review(
 p_review_id uuid,p_accept_evidence boolean,p_note text)
returns text language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_accept_evidence is null or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Decision and review note required'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=p_review_id for update;
 if not found or v.status<>'pending' then raise exception 'Pending review not found'; end if;
 if v.requested_by=auth.uid() then raise exception 'Second independent employee required'; end if;
 update public.gs_credit_identity_review_requests
 set status=case when p_accept_evidence then 'reviewed' else 'rejected' end,
 reviewed_by=auth.uid(), reviewed_at=now(), review_note=btrim(p_note)
 where id=v.id;
 -- Deliberately do NOT change gs_credit_customers.verification_status,
 -- gs_credit_account_registry_links.link_status or gs_credit_accounts.account_status.
 -- Human review is not proof of ownership; credit settlement stays blocked.
 return case when p_accept_evidence then 'reviewed_not_verified' else 'rejected' end;
end $$;
revoke all on function public.gs_staff_decide_credit_identity_review(uuid,boolean,text) from public,anon;
grant execute on function public.gs_staff_decide_credit_identity_review(uuid,boolean,text) to authenticated;

create or replace function public.gs_staff_list_credit_identity_reviews()
returns table(review_id uuid,registry_id uuid,account_id uuid,status text,
 evidence_reference text,requester_note text,requested_by uuid,requested_at timestamptz,
 reviewed_by uuid,reviewed_at timestamptz,review_note text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select r.id,r.registry_id,r.account_id,r.status,r.evidence_reference,
 r.requester_note,r.requested_by,r.requested_at,r.reviewed_by,r.reviewed_at,r.review_note
 from public.gs_credit_identity_review_requests r
 order by r.requested_at desc,r.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_identity_reviews() from public,anon;
grant execute on function public.gs_staff_list_credit_identity_reviews() to authenticated;
