-- Upgrade 458: a safety hold must prevent a later customer acknowledgement.
-- No identity verification or credit payment is enabled by this migration.
create or replace function public.gs_credit_block_acknowledgement_under_hold()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.response='acknowledged' and exists (
   select 1 from public.gs_credit_identity_customer_safety_holds h
   where h.onboarding_request_id=new.onboarding_request_id
 ) then raise exception 'Customer safety hold prevents identity acknowledgement'; end if;
 return new;
end $$;
drop trigger if exists gs_credit_acknowledgement_hold_guard
 on public.gs_credit_identity_onboarding_acknowledgements;
create trigger gs_credit_acknowledgement_hold_guard
 before insert or update on public.gs_credit_identity_onboarding_acknowledgements
 for each row execute function public.gs_credit_block_acknowledgement_under_hold();

-- New signature, retaining existing RPC for backward compatibility.
create function public.gs_credit_my_identity_onboarding_responses_v2()
returns table(request_id uuid,customer_reference text,request_status text,
 response text,responded_at timestamptz,hold_active boolean)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 return query select r.id,c.customer_reference::text,r.status::text,
 a.response::text,a.responded_at,(h.id is not null)
 from public.gs_credit_identity_onboarding_requests r
 join public.gs_credit_customers c on c.id=r.customer_id
 left join public.gs_credit_identity_onboarding_acknowledgements a
 on a.onboarding_request_id=r.id
 left join public.gs_credit_identity_customer_safety_holds h
 on h.onboarding_request_id=r.id
 where r.auth_user_id=auth.uid()
 order by r.requested_at desc,r.id desc limit 50;
end $$;
revoke all on function public.gs_credit_my_identity_onboarding_responses_v2() from public,anon;
grant execute on function public.gs_credit_my_identity_onboarding_responses_v2() to authenticated;
