-- Upgrade 435: authenticated customer's acknowledgement of onboarding request.
-- Acknowledgement is NOT proof of legal identity, ownership or credit consent.
create table if not exists public.gs_credit_identity_onboarding_acknowledgements (
 id uuid primary key default gen_random_uuid(),
 onboarding_request_id uuid not null unique references public.gs_credit_identity_onboarding_requests(id),
 auth_user_id uuid not null references auth.users(id),
 response text not null check(response in ('acknowledged','disputed')),
 responded_at timestamptz not null default now()
);
create index if not exists gs_credit_onboarding_ack_user_idx
 on public.gs_credit_identity_onboarding_acknowledgements(auth_user_id,responded_at desc);
alter table public.gs_credit_identity_onboarding_acknowledgements enable row level security;
revoke all on public.gs_credit_identity_onboarding_acknowledgements from public,anon,authenticated;

create or replace function public.gs_credit_respond_to_identity_onboarding(
 p_request_id uuid,p_response text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.gs_credit_identity_onboarding_requests%rowtype; v_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_response is null or p_response not in ('acknowledged','disputed') then
  raise exception 'Response must be acknowledged or disputed'; end if;
 select * into r from public.gs_credit_identity_onboarding_requests
 where id=p_request_id for update;
 if not found or r.status<>'pending' or r.auth_user_id<>auth.uid() then
  raise exception 'No pending onboarding request for current user'; end if;
 if exists(select 1 from public.gs_credit_identity_onboarding_acknowledgements
   where onboarding_request_id=p_request_id) then
  raise exception 'Response already recorded; contact staff for correction'; end if;
 insert into public.gs_credit_identity_onboarding_acknowledgements
 (onboarding_request_id,auth_user_id,response)
 values(r.id,auth.uid(),p_response) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_credit_respond_to_identity_onboarding(uuid,text) from public,anon;
grant execute on function public.gs_credit_respond_to_identity_onboarding(uuid,text) to authenticated;

create or replace function public.gs_credit_my_identity_onboarding_responses()
returns table(request_id uuid,customer_reference text,request_status text,
 response text,responded_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return query select r.id,c.customer_reference,r.status,a.response,a.responded_at
 from public.gs_credit_identity_onboarding_requests r
 join public.gs_credit_customers c on c.id=r.customer_id
 left join public.gs_credit_identity_onboarding_acknowledgements a
  on a.onboarding_request_id=r.id
 where r.auth_user_id=auth.uid()
 order by r.requested_at desc,r.id desc limit 50;
end $$;
revoke all on function public.gs_credit_my_identity_onboarding_responses() from public,anon;
grant execute on function public.gs_credit_my_identity_onboarding_responses() to authenticated;

create or replace function public.gs_staff_list_credit_identity_onboarding_responses(p_request_id uuid)
returns table(response text,responded_at timestamptz,auth_user_id uuid)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select a.response,a.responded_at,a.auth_user_id
 from public.gs_credit_identity_onboarding_acknowledgements a
 where a.onboarding_request_id=p_request_id;
end $$;
revoke all on function public.gs_staff_list_credit_identity_onboarding_responses(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_identity_onboarding_responses(uuid) to authenticated;
-- No RPC here verifies a binding, authorizes payment or posts a credit debit.
