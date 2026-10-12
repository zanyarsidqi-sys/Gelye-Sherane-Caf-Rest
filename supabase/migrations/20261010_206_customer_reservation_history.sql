-- Upgrade 206: customer-linked cashier reservation requests and private history.
-- Public anonymous reservations remain unlinked to avoid unsafe identity matching.
alter table public.gs_public_reservation_requests
 add column if not exists cafe_customer_id bigint references public.gs_cafe_customer_profiles(id) on delete restrict;
create index if not exists gs_reservation_customer_history_idx
 on public.gs_public_reservation_requests(cafe_customer_id,created_at desc)
 where cafe_customer_id is not null;

-- Preserve old cashier RPC for existing clients; the new RPC accepts customer ID.
create or replace function public.gs_cashier_create_customer_reservation(
 p_customer_id bigint,p_name text,p_phone text,p_requested_at timestamptz,
 p_party_size integer,p_notes text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_name text; v_phone text;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Table edit permission required'; end if;
 if p_customer_id is not null then
  select c.full_name,c.phone into v_name,v_phone
  from public.gs_cafe_customer_profiles c where c.id=p_customer_id;
  if not found then raise exception 'Customer not found'; end if;
  -- Existing customer's name is authoritative. Phone may be entered for
  -- this reservation without changing the stored profile.
  v_phone := coalesce(nullif(trim(coalesce(p_phone,'')),''),v_phone);
 else
  v_name := trim(coalesce(p_name,''));
  v_phone := trim(coalesce(p_phone,''));
 end if;
 if length(coalesce(v_name,'')) not between 2 and 100
    or length(coalesce(v_phone,'')) not between 6 and 30
    or p_party_size not between 1 and 30
    or p_requested_at <= now() or p_requested_at > now()+interval '90 days'
    or length(coalesce(p_notes,'')) > 500 then
  raise exception 'Invalid reservation request'; end if;
 insert into public.gs_public_reservation_requests(
  customer_name,phone,requested_at,party_size,notes,submission_channel,
  submitted_by,cafe_customer_id)
 values(v_name,v_phone,p_requested_at,p_party_size,
  nullif(trim(coalesce(p_notes,'')),''),'cashier',auth.uid(),p_customer_id)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_cashier_create_customer_reservation(bigint,text,text,timestamptz,integer,text) from public,anon;
grant execute on function public.gs_cashier_create_customer_reservation(bigint,text,text,timestamptz,integer,text) to authenticated;

create or replace function public.gs_cafe_customer_reservation_history(p_customer_id bigint)
returns table(reservation_id uuid,requested_at timestamptz,party_size integer,
 status text,submission_channel text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.gs_can_access('customers','can_view') or
    public.gs_can_access('tables','can_view')) then
  raise exception 'Customer view permission required'; end if;
 return query select r.id,r.requested_at,r.party_size,r.status,r.submission_channel,r.created_at
 from public.gs_public_reservation_requests r
 where r.cafe_customer_id=p_customer_id order by r.created_at desc limit 500;
end $$;
revoke all on function public.gs_cafe_customer_reservation_history(bigint) from public,anon;
grant execute on function public.gs_cafe_customer_reservation_history(bigint) to authenticated;
