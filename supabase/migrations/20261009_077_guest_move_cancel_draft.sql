-- Upgrade 77: safe guest-move cancellation and visit state inspection.
-- Does NOT execute guest moves or modify table occupancy.
create table if not exists public.gs_table_guest_move_cancellation_audit (
 id bigint generated always as identity primary key,
 request_id bigint not null unique references public.gs_table_guest_move_requests(id),
 cancelled_by uuid not null references auth.users(id),
 cancellation_reason text not null check(length(cancellation_reason) between 5 and 500),
 cancelled_at timestamptz not null default now()
);
alter table public.gs_table_guest_move_cancellation_audit enable row level security;
revoke all on public.gs_table_guest_move_cancellation_audit from public,anon,authenticated;

create or replace function public.gs_cancel_table_guest_move(
 p_request_id bigint, p_reason text
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_request public.gs_table_guest_move_requests%rowtype;
begin
 if auth.uid() is null or not public.gs_can_access('tables','can_edit') then
  raise exception 'Guest move cancellation permission denied'; end if;
 if p_request_id is null or p_reason is null or length(btrim(p_reason))<5
  or length(p_reason)>500 then raise exception 'Valid cancellation reason required'; end if;
 select * into v_request from public.gs_table_guest_move_requests
  where id=p_request_id for update;
 if not found then raise exception 'Guest move request not found'; end if;
 if v_request.status='cancelled' then return false; end if;
 if v_request.status<>'pending' then
  raise exception 'Only pending guest moves may be cancelled'; end if;
 update public.gs_table_guest_move_requests set status='cancelled'
  where id=p_request_id and status='pending';
 -- Existing request schema does not have cancellation metadata. Store a
 -- durable audit record without changing the original request payload.
 insert into public.gs_table_guest_move_cancellation_audit(
  request_id,cancelled_by,cancellation_reason)
 values(p_request_id,auth.uid(),btrim(p_reason));
 return true;
end; $$;

revoke all on function public.gs_cancel_table_guest_move(bigint,text) from public,anon;
grant execute on function public.gs_cancel_table_guest_move(bigint,text) to authenticated;
-- Execution remains blocked until reservation conflict checks, authoritative
-- item-level payment allocation and atomic guest/table updates are verified.
