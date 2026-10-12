-- Upgrade 466: customer concern is a hard stop for authorization status escalation.
-- Existing read-only requests remain visible for investigation; no debit or consent is enabled.
create or replace function public.gs_credit_authorization_concern_guard()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.gs_credit_authorization_customer_concerns c
           where c.authorization_request_id=new.id)
    and (new.status is distinct from old.status)
    and new.status not in ('cancelled','expired','rejected') then
   raise exception 'Customer concern on authorization; escalation blocked';
 end if;
 return new;
end $$;
drop trigger if exists gs_credit_authorization_concern_guard on public.gs_credit_customer_authorization_requests;
create trigger gs_credit_authorization_concern_guard before update of status
on public.gs_credit_customer_authorization_requests for each row
execute function public.gs_credit_authorization_concern_guard();
revoke all on function public.gs_credit_authorization_concern_guard() from public,anon,authenticated;

-- Staff may inspect concern metadata only with Credit Management viewing rights.
create or replace function public.gs_staff_credit_authorization_concerns(p_review_id uuid)
returns table(invoice_reference text, reported_at timestamptz, concern_reason text)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select q.invoice_reference,c.created_at,c.reason
 from public.gs_credit_authorization_customer_concerns c
 join public.gs_credit_customer_authorization_requests q on q.id=c.authorization_request_id
 where q.review_id=p_review_id order by c.created_at desc limit 100;
end $$;
revoke all on function public.gs_staff_credit_authorization_concerns(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_concerns(uuid) to authenticated;
