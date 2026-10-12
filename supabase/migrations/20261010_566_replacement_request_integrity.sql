-- Upgrade 566: immutable committed replacement receipts and a scoped recovery status.
-- Prevent an accidental or compromised client path from rewriting historical receipts.
create or replace function public.gs_guard_replacement_request_immutable()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 raise exception 'Committed replacement request receipts are immutable';
end $$;

drop trigger if exists gs_replacement_request_immutable on public.gs_table_replacement_requests;
create trigger gs_replacement_request_immutable
before update or delete on public.gs_table_replacement_requests
for each row execute function public.gs_guard_replacement_request_immutable();

-- A read-only diagnostic endpoint. A missing record does not prove the
-- original RPC failed: it may still be executing on another connection.
create or replace function public.gs_table_replacement_request_status(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_receipt record;
begin
 if auth.uid() is null or not public.gs_can_access('table_orders','can_view') then
  raise exception 'Table order viewing permission required';
 end if;
 if p_request_id is null then raise exception 'Request identity required'; end if;
 select request_id, result, created_at into v_receipt
 from public.gs_table_replacement_requests
 where request_id=p_request_id and actor_id=auth.uid();
 if not found then
  return jsonb_build_object('status','not_recorded','retry_safe',false);
 end if;
 return jsonb_build_object('status','committed','retry_safe',false,
   'result',v_receipt.result,'committed_at',v_receipt.created_at);
end $$;
revoke all on function public.gs_table_replacement_request_status(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_request_status(uuid) to authenticated;
