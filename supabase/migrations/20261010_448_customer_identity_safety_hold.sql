-- Upgrade 448: customer-initiated safety hold for disputed identity onboarding.
-- Even a previous acknowledgement may be disputed later. Holds are irreversible via customer API.
create table if not exists public.gs_credit_identity_customer_safety_holds (
 id uuid primary key default gen_random_uuid(),
 onboarding_request_id uuid not null unique references public.gs_credit_identity_onboarding_requests(id),
 auth_user_id uuid not null references auth.users(id),
 reason text not null check(length(btrim(reason)) between 10 and 1000),
 created_at timestamptz not null default now()
);
create index if not exists gs_credit_identity_customer_safety_holds_user
 on public.gs_credit_identity_customer_safety_holds(auth_user_id,created_at desc);
alter table public.gs_credit_identity_customer_safety_holds enable row level security;
revoke all on public.gs_credit_identity_customer_safety_holds from public,anon,authenticated;

create or replace function public.gs_credit_raise_identity_safety_hold(p_request_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 10 and 1000
 then raise exception 'Reason must be 10-1000 characters'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests
 where id=p_request_id for update;
 if not found or r.auth_user_id<>auth.uid() then
   raise exception 'Onboarding request not found for authenticated customer'; end if;
 insert into public.gs_credit_identity_customer_safety_holds
 (onboarding_request_id,auth_user_id,reason)
 values(r.id,auth.uid(),btrim(p_reason))
 on conflict (onboarding_request_id) do nothing returning id into v_id;
 if v_id is null then
   select h.id into v_id from public.gs_credit_identity_customer_safety_holds h
   where h.onboarding_request_id=r.id and h.auth_user_id=auth.uid();
 end if;
 return v_id;
end $$;
revoke all on function public.gs_credit_raise_identity_safety_hold(uuid,text) from public,anon;
grant execute on function public.gs_credit_raise_identity_safety_hold(uuid,text) to authenticated;

create or replace function public.gs_credit_my_identity_safety_holds()
returns table(request_id uuid,reason text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return query select h.onboarding_request_id,h.reason,h.created_at
 from public.gs_credit_identity_customer_safety_holds h
 where h.auth_user_id=auth.uid() order by h.created_at desc limit 100;
end $$;
revoke all on function public.gs_credit_my_identity_safety_holds() from public,anon;
grant execute on function public.gs_credit_my_identity_safety_holds() to authenticated;

create or replace function public.gs_staff_credit_identity_safety_hold_status(p_request_id uuid)
returns table(hold_active boolean,reason text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer permission required'; end if;
 if not exists(select 1 from public.gs_credit_identity_onboarding_requests where id=p_request_id)
 then raise exception 'Onboarding request not found'; end if;
 return query select h.id is not null, h.reason, h.created_at
 from (select 1) x left join public.gs_credit_identity_customer_safety_holds h
 on h.onboarding_request_id=p_request_id;
end $$;
revoke all on function public.gs_staff_credit_identity_safety_hold_status(uuid) from public,anon;
grant execute on function public.gs_staff_credit_identity_safety_hold_status(uuid) to authenticated;

-- Enforce the hold on independent external evidence review, even if UI is bypassed.
-- Original RPC signature remains unchanged; guard triggers for all writes via the table.
create or replace function public.gs_credit_reject_review_when_safety_hold()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_request_id uuid;
begin
 select e.onboarding_request_id into v_request_id
 from public.gs_credit_identity_external_verification_evidence e
 where e.id=new.evidence_id;
 if exists(select 1 from public.gs_credit_identity_customer_safety_holds h
           where h.onboarding_request_id=v_request_id) then
   raise exception 'Customer identity safety hold: evidence review is blocked';
 end if;
 return new;
end $$;
drop trigger if exists gs_credit_external_review_safety_hold on public.gs_credit_identity_external_evidence_reviews;
create trigger gs_credit_external_review_safety_hold before insert or update
 on public.gs_credit_identity_external_evidence_reviews for each row
 execute function public.gs_credit_reject_review_when_safety_hold();
