-- Upgrade 425: time-bound authorization requests, without customer consent or debit.
alter table public.gs_credit_customer_authorization_requests
  add column if not exists expires_at timestamptz;
update public.gs_credit_customer_authorization_requests
  set expires_at = requested_at + interval '24 hours'
  where expires_at is null;
alter table public.gs_credit_customer_authorization_requests
  alter column expires_at set default (now() + interval '24 hours');
alter table public.gs_credit_customer_authorization_requests
  alter column expires_at set not null;

-- Prevent new requests from bypassing the expiration period, even through a security-definer RPC.
create or replace function public.gs_credit_authorization_set_expiry()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.expires_at := statement_timestamp() + interval '24 hours';
  elsif new.expires_at is distinct from old.expires_at then
    raise exception 'Authorization request expiration cannot be changed';
  end if;
  return new;
end $$;
drop trigger if exists gs_credit_authorization_expiry_guard on public.gs_credit_customer_authorization_requests;
create trigger gs_credit_authorization_expiry_guard
before insert or update on public.gs_credit_customer_authorization_requests
for each row execute function public.gs_credit_authorization_set_expiry();

create or replace function public.gs_staff_credit_authorization_expiry_checks(p_request_id uuid)
returns table(check_name text, check_status text, explanation text)
language plpgsql security definer set search_path = '' as $$
declare q public.gs_credit_customer_authorization_requests%rowtype;
begin
  if auth.uid() is null
    or not coalesce(public.gs_can_access('credit_management','can_view'),false)
  then raise exception 'Credit Management viewer required'; end if;
  select * into q from public.gs_credit_customer_authorization_requests where id=p_request_id;
  if not found then raise exception 'Authorization request not found'; end if;
  return query select 'request'::text,
    case when q.status = 'requested' then 'pending' else 'cancelled' end::text,
    'A staff request does not establish customer consent'::text;
  return query select 'expiry'::text,
    case when q.expires_at > statement_timestamp() then 'within_window' else 'expired' end::text,
    ('Expires at ' || q.expires_at::text)::text;
  return query select 'customer_authentication'::text,'unverified'::text,
    'No authenticated customer consent mechanism exists'::text;
  return query select 'credit_payment'::text,'blocked'::text,
    'No debit or settlement is permitted'::text;
end $$;
revoke all on function public.gs_staff_credit_authorization_expiry_checks(uuid) from public,anon;
grant execute on function public.gs_staff_credit_authorization_expiry_checks(uuid) to authenticated;
