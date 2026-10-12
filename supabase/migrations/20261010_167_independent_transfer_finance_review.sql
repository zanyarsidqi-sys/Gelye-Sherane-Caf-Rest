-- Upgrade 167: independent, immutable transfer FINANCIAL REVIEW record.
-- This is NOT approval and never permits execution.
create table if not exists public.gs_table_transfer_finance_reviews(
 id bigint generated always as identity primary key,
 request_id bigint not null references public.gs_table_bill_transfer_requests(id),
 reviewed_by uuid not null,
 reviewed_at timestamptz not null default now(),
 review_ready boolean not null,
 blocker_codes text[] not null,
 requested_value_iqd bigint not null check(requested_value_iqd>=0),
 request_status text not null,
 outcome text not null default 'review_only' check(outcome='review_only'),
 execution_permitted boolean not null default false check(not execution_permitted)
);
create index if not exists gs_table_transfer_finance_reviews_request_idx
 on public.gs_table_transfer_finance_reviews(request_id,reviewed_at desc);
alter table public.gs_table_transfer_finance_reviews enable row level security;
revoke all on public.gs_table_transfer_finance_reviews from public,anon,authenticated;
-- No direct write policy. Even privileged writes must not rewrite review evidence.
create or replace function public.gs_reject_transfer_finance_review_mutation()
returns trigger language plpgsql set search_path='' as $$
begin
 raise exception 'Financial transfer review evidence is immutable';
end; $$;
drop trigger if exists gs_transfer_finance_review_immutable
 on public.gs_table_transfer_finance_reviews;
create trigger gs_transfer_finance_review_immutable
 before update or delete on public.gs_table_transfer_finance_reviews
 for each row execute function public.gs_reject_transfer_finance_review_mutation();

create or replace function public.gs_record_table_transfer_finance_review(p_request_id bigint)
returns bigint
language plpgsql volatile security definer set search_path='' as $$
declare
 v_req public.gs_table_bill_transfer_requests%rowtype;
 v_check record;
 v_id bigint;
begin
 if auth.uid() is null
   or coalesce(auth.jwt()->>'aal','')<>'aal2'
   or not public.gs_can_access('invoices_payments','can_edit')
   or not public.gs_can_access('table_orders','can_view') then
   raise exception 'Finance MFA review permission denied';
 end if;
 if p_request_id is null then raise exception 'Request ID required'; end if;
 select * into v_req from public.gs_table_bill_transfer_requests
  where id=p_request_id for update;
 if not found then raise exception 'Transfer request not found'; end if;
 if v_req.requested_by=auth.uid() then
   raise exception 'Independent reviewer required';
 end if;
 select * into v_check
 from public.gs_validate_table_bill_transfer_request(p_request_id);
 if not found then raise exception 'Validation unavailable'; end if;
 insert into public.gs_table_transfer_finance_reviews(
  request_id,reviewed_by,review_ready,blocker_codes,
  requested_value_iqd,request_status)
 values(v_req.id,auth.uid(),coalesce(v_check.review_passed,false),
  coalesce(v_check.blocker_codes,array[]::text[]),
  coalesce(v_check.requested_value_iqd,0),v_req.status)
 returning id into v_id;
 return v_id;
end; $$;
revoke all on function public.gs_record_table_transfer_finance_review(bigint)
 from public,anon;
grant execute on function public.gs_record_table_transfer_finance_review(bigint)
 to authenticated;
