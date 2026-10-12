-- Upgrade 420: consent outreach tracking only. This is NOT customer consent.
create table if not exists public.gs_credit_consent_outreach (
 id uuid primary key default gen_random_uuid(),
 review_id uuid not null references public.gs_credit_identity_review_requests(id),
 registry_id uuid not null references public.gs_credit_account_registry_links(registry_id),
 channel text not null check(channel in ('in_person','phone','sms','email','other')),
 note text not null check(length(btrim(note)) between 10 and 1000),
 status text not null default 'requested' check(status='requested'),
 requested_by uuid not null references auth.users(id),
 requested_at timestamptz not null default now()
);
create index if not exists gs_credit_consent_outreach_review_idx on public.gs_credit_consent_outreach(review_id,requested_at desc);
alter table public.gs_credit_consent_outreach enable row level security;
revoke all on public.gs_credit_consent_outreach from public,anon,authenticated;
create or replace function public.gs_staff_request_credit_consent_outreach(
 p_review_id uuid,p_channel text,p_note text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.gs_credit_identity_review_requests%rowtype;
 l public.gs_credit_account_registry_links%rowtype;
 new_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit Management editor required'; end if;
 if p_channel is null or p_channel not in ('in_person','phone','sms','email','other')
 or p_note is null or length(btrim(p_note)) not between 10 and 1000
 then raise exception 'Valid outreach channel and note required'; end if;
 select * into v from public.gs_credit_identity_review_requests where id=p_review_id for update;
 if not found then raise exception 'Identity review not found'; end if;
 select * into l from public.gs_credit_account_registry_links where registry_id=v.registry_id for update;
 if l.registry_id is null or l.account_id<>v.account_id or l.link_status<>'pending'
 then raise exception 'Pending matching credit link required'; end if;
 insert into public.gs_credit_consent_outreach(review_id,registry_id,channel,note,requested_by)
 values(v.id,v.registry_id,p_channel,btrim(p_note),auth.uid()) returning id into new_id;
 return new_id;
end $$;
revoke all on function public.gs_staff_request_credit_consent_outreach(uuid,text,text) from public,anon;
grant execute on function public.gs_staff_request_credit_consent_outreach(uuid,text,text) to authenticated;
create or replace function public.gs_staff_list_credit_consent_outreach(p_review_id uuid)
returns table(channel text,note text,status text,requested_by uuid,requested_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_view'),false)
 then raise exception 'Credit Management viewer required'; end if;
 return query select o.channel,o.note,o.status,o.requested_by,o.requested_at
 from public.gs_credit_consent_outreach o where o.review_id=p_review_id
 order by o.requested_at desc,o.id desc limit 100;
end $$;
revoke all on function public.gs_staff_list_credit_consent_outreach(uuid) from public,anon;
grant execute on function public.gs_staff_list_credit_consent_outreach(uuid) to authenticated;
