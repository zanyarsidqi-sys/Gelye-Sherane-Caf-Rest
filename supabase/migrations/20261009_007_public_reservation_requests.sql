-- Public reservation REQUESTS, not confirmed bookings.
create table if not exists public.gs_public_reservation_requests (
 id uuid primary key default gen_random_uuid(),
 customer_name text not null check (char_length(customer_name) between 2 and 100),
 phone text not null check (char_length(phone) between 6 and 30),
 requested_at timestamptz not null,
 party_size integer not null check (party_size between 1 and 30),
 notes text check (char_length(notes) <= 500),
 status text not null default 'pending' check (status in ('pending','approved','declined','cancelled')),
 created_at timestamptz not null default now(),
 constraint future_reservation check (requested_at > created_at)
);
alter table public.gs_public_reservation_requests enable row level security;
revoke all on public.gs_public_reservation_requests from anon, authenticated;
create or replace function public.gs_submit_reservation_request(p_name text, p_phone text, p_requested_at timestamptz, p_party_size integer, p_notes text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
 if length(trim(coalesce(p_name,''))) not between 2 and 100 or length(trim(coalesce(p_phone,''))) not between 6 and 30 or p_party_size not between 1 and 30 or p_requested_at <= now() or p_requested_at > now() + interval '90 days' or length(coalesce(p_notes,'')) > 500 then
  raise exception 'Invalid reservation request';
 end if;
 insert into public.gs_public_reservation_requests(customer_name,phone,requested_at,party_size,notes)
 values(trim(p_name),trim(p_phone),p_requested_at,p_party_size,nullif(trim(coalesce(p_notes,'')),'')) returning id into new_id;
 return new_id;
end $$;
revoke all on function public.gs_submit_reservation_request(text,text,timestamptz,integer,text) from public;
grant execute on function public.gs_submit_reservation_request(text,text,timestamptz,integer,text) to anon,authenticated;
-- Production deployment must add rate limiting/CAPTCHA at the edge before opening anonymous submissions.
