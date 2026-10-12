-- Upgrade 407: auditable evidence review, not authoritative credit approval.
create table if not exists public.gs_motel_credit_verification_review_events (
 id uuid primary key default extensions.gen_random_uuid(),
 request_id uuid not null references public.gs_motel_credit_verification_requests(id),
 review_type text not null check(review_type in
 ('ownership_evidence_requested','ownership_evidence_received',
  'balance_provider_required','customer_consent_required','review_note')),
 note text not null check(length(btrim(note)) between 10 and 1000),
 reviewed_by uuid not null references auth.users(id),
 reviewed_at timestamptz not null default now()
);
create index if not exists gs_motel_credit_review_events_request_idx
 on public.gs_motel_credit_verification_review_events(request_id,reviewed_at desc);
alter table public.gs_motel_credit_verification_review_events enable row level security;
revoke all on public.gs_motel_credit_verification_review_events from public,anon,authenticated;

create or replace function public.gs_staff_note_motel_credit_verification(
 p_request_id uuid,p_review_type text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare q public.gs_motel_credit_verification_requests%rowtype;
 v_id uuid;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_edit'),false)
 then raise exception 'Authorized finance editor required'; end if;
 if p_review_type not in ('ownership_evidence_requested','ownership_evidence_received',
  'balance_provider_required','customer_consent_required','review_note')
 or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Invalid review type or note (10-1000 characters)'; end if;
 select * into q from public.gs_motel_credit_verification_requests
 where id=p_request_id for update;
 if not found or q.status<>'pending' then
  raise exception 'Only pending credit requests can be reviewed'; end if;
 insert into public.gs_motel_credit_verification_review_events
 (request_id,review_type,note,reviewed_by)
 values(q.id,p_review_type,btrim(p_note),auth.uid()) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_note_motel_credit_verification(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_note_motel_credit_verification(uuid,text,text) to authenticated;

create or replace function public.gs_staff_list_motel_credit_review_events(p_request_id uuid)
returns table(review_type text,note text,reviewed_by uuid,reviewed_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Authorized finance viewer required'; end if;
 return query select e.review_type,e.note,e.reviewed_by,e.reviewed_at
 from public.gs_motel_credit_verification_review_events e
 where e.request_id=p_request_id order by e.reviewed_at desc,e.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_motel_credit_review_events(uuid) from public,anon;
grant execute on function public.gs_staff_list_motel_credit_review_events(uuid) to authenticated;
