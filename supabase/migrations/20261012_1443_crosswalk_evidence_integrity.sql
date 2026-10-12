-- Finance crosswalk evidence integrity hardening; no source identity certification or payment posting.
-- Prevent two non-rejected evidence candidates from claiming the same cafe order or motel invoice.
create unique index if not exists gs_financial_crosswalk_one_active_order
 on public.gs_financial_crosswalk_evidence(cafe_order_id)
 where review_state <> 'rejected';
create unique index if not exists gs_financial_crosswalk_one_active_invoice
 on public.gs_financial_crosswalk_evidence(motel_invoice_id)
 where review_state <> 'rejected';

-- Evidence identity, provenance and reviewer audit data are immutable once written.
-- Only the pending -> reviewed_unverified/rejected decision is permitted.
create or replace function public.gs_financial_crosswalk_evidence_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op = 'DELETE' then
  raise exception 'Finance identity evidence cannot be deleted' using errcode='42501';
 end if;
 if tg_op = 'UPDATE' then
  if row(old.id,old.cafe_order_id,old.motel_invoice_id,old.evidence_reference,
     old.evidence_sha256,old.evidence_description,old.submitted_by,old.submitted_at)
     is distinct from
     row(new.id,new.cafe_order_id,new.motel_invoice_id,new.evidence_reference,
     new.evidence_sha256,new.evidence_description,new.submitted_by,new.submitted_at)
  then raise exception 'Submitted finance evidence is immutable' using errcode='42501'; end if;
  if old.review_state <> 'pending' or new.review_state not in ('reviewed_unverified','rejected')
     or new.reviewed_by is null or new.reviewed_by=old.submitted_by
     or new.reviewed_at is null or new.review_note is null
     or length(btrim(new.review_note)) not between 20 and 1000
  then raise exception 'Only independent final review is permitted' using errcode='42501'; end if;
 end if;
 return new;
end $$;
revoke all on function public.gs_financial_crosswalk_evidence_guard() from public,anon,authenticated;
drop trigger if exists gs_financial_crosswalk_evidence_guard_trg on public.gs_financial_crosswalk_evidence;
create trigger gs_financial_crosswalk_evidence_guard_trg
 before update or delete on public.gs_financial_crosswalk_evidence
 for each row execute function public.gs_financial_crosswalk_evidence_guard();
