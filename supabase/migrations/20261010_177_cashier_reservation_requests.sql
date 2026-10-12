-- Upgrade 177: cashier-originated reservation requests.
-- Reuses the existing public reservation review/approval capacity guard.
alter table public.gs_public_reservation_requests
 add column if not exists submission_channel text not null default 'website'
 check(submission_channel in ('website','cashier'));
alter table public.gs_public_reservation_requests
 add column if not exists submitted_by uuid references auth.users(id);
create index if not exists gs_reservation_channel_idx
 on public.gs_public_reservation_requests(submission_channel,created_at desc);

create or replace function public.gs_cashier_create_reservation_request(
 p_name text,p_phone text,p_requested_at timestamptz,p_party_size integer,
 p_notes text default null)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not (
  public.gs_can_access('tables','can_edit') or
  public.cafe_can_manage_website('edit')
 ) then raise exception 'Not authorized to create cashier reservations'; end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 100
 or length(trim(coalesce(p_phone,''))) not between 6 and 30
 or p_party_size not between 1 and 30
 or p_requested_at <= now()
 or p_requested_at > now()+interval '90 days'
 or length(coalesce(p_notes,'')) > 500 then
  raise exception 'Invalid reservation request';
 end if;
 insert into public.gs_public_reservation_requests(
  customer_name,phone,requested_at,party_size,notes,submission_channel,submitted_by)
 values(trim(p_name),trim(p_phone),p_requested_at,p_party_size,
  nullif(trim(coalesce(p_notes,'')),''),'cashier',auth.uid())
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_cashier_create_reservation_request(
 text,text,timestamptz,integer,text) from public,anon;
grant execute on function public.gs_cashier_create_reservation_request(
 text,text,timestamptz,integer,text) to authenticated;
