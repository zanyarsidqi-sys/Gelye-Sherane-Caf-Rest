-- Upgrade 165: finance review preparation only. No approval, transfer or posting.
-- Reuses Upgrade 161 checks, and deliberately never returns permission to execute.
create or replace function public.gs_prepare_table_bill_transfer_approval(p_request_id bigint)
returns table(
 request_id bigint, review_ready boolean, execution_permitted boolean,
 requested_value_iqd bigint, blocker_codes text[],
 next_action text, reviewer_id uuid, reviewed_at timestamptz
)
language plpgsql volatile security definer set search_path='' as $$
declare v record;
begin
 if auth.uid() is null
    or not public.gs_can_access('table_orders','can_view')
    or not public.gs_can_access('invoices_payments','can_view') then
   raise exception 'Transfer approval preparation permission denied';
 end if;
 if p_request_id is null then raise exception 'Request ID required'; end if;
 -- Read-only preflight result. An actual approval needs immutable evidence,
 -- independent reviewer, fresh locks and a fully atomic transfer operation.
 select * into v from public.gs_validate_table_bill_transfer_request(p_request_id);
 if not found then raise exception 'Transfer validation unavailable'; end if;
 return query select v.request_id,
    coalesce(v.review_passed,false), false,
    v.requested_value_iqd, v.blocker_codes,
    case when not coalesce(v.review_passed,false)
      then 'Resolve all financial blockers and repeat validation'
      else 'Await independent approval and atomic allocation implementation'
    end::text,
    auth.uid(), clock_timestamp();
end; $$;
revoke all on function public.gs_prepare_table_bill_transfer_approval(bigint)
 from public,anon;
grant execute on function public.gs_prepare_table_bill_transfer_approval(bigint)
 to authenticated;
