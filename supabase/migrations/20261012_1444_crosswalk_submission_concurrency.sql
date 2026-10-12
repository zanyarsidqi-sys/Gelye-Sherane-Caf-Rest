-- Finance crosswalk submission concurrency hardening. No identity or settlement certification.
-- SECURITY INVOKER: caller is already authorized by the submission RPC; advisory locks serialize
-- concurrent submissions for the same order and invoice, with unique indexes as final defense.
create or replace function public.gs_financial_crosswalk_submission_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.review_state <> 'pending' or new.reviewed_by is not null or new.reviewed_at is not null then
  raise exception 'Evidence must be submitted pending independent review' using errcode='22023';
 end if;
 -- Lock order then invoice in a stable sequence for all submissions.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gs_crosswalk_order:' || new.cafe_order_id::text,0));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('gs_crosswalk_invoice:' || new.motel_invoice_id::text,0));
 if exists(select 1 from public.gs_financial_crosswalk_evidence e
           where e.cafe_order_id=new.cafe_order_id and e.review_state <> 'rejected') then
  raise exception 'Active crosswalk evidence already exists for this cafe order' using errcode='23505';
 end if;
 if exists(select 1 from public.gs_financial_crosswalk_evidence e
           where e.motel_invoice_id=new.motel_invoice_id and e.review_state <> 'rejected') then
  raise exception 'Active crosswalk evidence already exists for this motel invoice' using errcode='23505';
 end if;
 return new;
end $$;
revoke all on function public.gs_financial_crosswalk_submission_guard() from public,anon,authenticated;
drop trigger if exists gs_financial_crosswalk_submission_guard_trg on public.gs_financial_crosswalk_evidence;
create trigger gs_financial_crosswalk_submission_guard_trg
 before insert on public.gs_financial_crosswalk_evidence
 for each row execute function public.gs_financial_crosswalk_submission_guard();
