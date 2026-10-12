-- Upgrade 79: secure reservation QR lookup foundation, NOT meal entitlement authorization.
-- Trusted motel backend must provision unpredictable tokens and independently
-- validate reservation state, room and guest entitlements before any delivery.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.gs_motel_reservation_qr_tokens (
 id bigint generated always as identity primary key,
 reservation_id uuid not null,
 room_label text not null,
 token_sha256 text not null unique check(length(token_sha256)=64),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 last_lookup_at timestamptz
);
create index if not exists gs_motel_reservation_qr_tokens_reservation_idx
 on public.gs_motel_reservation_qr_tokens(reservation_id);
alter table public.gs_motel_reservation_qr_tokens enable row level security;
revoke all on public.gs_motel_reservation_qr_tokens from public,anon,authenticated;
-- No self-service token issuance. Provision from a trusted motel backend only.
-- QR is a locator, never proof of payment or guest authorization.
create or replace function public.gs_lookup_motel_reservation_qr(p_token text)
returns table(reservation_id uuid, room_label text, verification_status text)
language plpgsql security definer set search_path='' as $$
declare v_token_hash text;
begin
 if auth.uid() is null or not public.gs_can_access('motel_orders','can_view')
 then raise exception 'Motel reservation lookup access denied'; end if;
 if p_token is null or length(p_token)<32 or length(p_token)>512
 then raise exception 'Invalid QR token'; end if;
 v_token_hash:=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex');
 return query
 select t.reservation_id,t.room_label,
   'qr_locator_only_backend_verification_required'::text
 from public.gs_motel_reservation_qr_tokens t
 where t.token_sha256=v_token_hash
   and t.revoked_at is null and t.expires_at>now()
 limit 1;
 -- No automatic verification timestamps, payment updates, or entitlement grants.
end; $$;
revoke all on function public.gs_lookup_motel_reservation_qr(text) from public,anon;
grant execute on function public.gs_lookup_motel_reservation_qr(text) to authenticated;
