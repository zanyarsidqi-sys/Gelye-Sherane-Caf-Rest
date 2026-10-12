-- Upgrade 402: restricted credit barcode identity lookup (NO debit, NO balance claim).
create table if not exists public.gs_motel_credit_barcode_registry (
 id uuid primary key default extensions.gen_random_uuid(),
 barcode_sha256 text not null unique check (barcode_sha256 ~ '^[0-9a-f]{64}$'),
 display_label text not null check (length(btrim(display_label)) between 1 and 120),
 account_reference text not null unique,
 account_status text not null default 'pending_verification'
   check (account_status in ('pending_verification','active','suspended')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
alter table public.gs_motel_credit_barcode_registry enable row level security;
revoke all on public.gs_motel_credit_barcode_registry from public,anon,authenticated;

-- Only a privileged credit administrator may provision an identity reference.
-- An 'active' registry entry does NOT prove ownership or sufficient balance.
create or replace function public.gs_staff_register_motel_credit_barcode(
 p_barcode text, p_account_reference text, p_display_label text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('credit_management','can_edit'),false)
 then raise exception 'Credit management editor required'; end if;
 if p_barcode is null or length(btrim(p_barcode)) not between 6 and 128
 or p_account_reference is null or length(btrim(p_account_reference)) not between 1 and 100
 or p_display_label is null or length(btrim(p_display_label)) not between 1 and 120
 then raise exception 'Invalid credit identity fields'; end if;
 insert into public.gs_motel_credit_barcode_registry
 (barcode_sha256,account_reference,display_label,created_by)
 values (encode(extensions.digest(btrim(p_barcode),'sha256'),'hex'),
         btrim(p_account_reference),btrim(p_display_label),auth.uid())
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.gs_staff_register_motel_credit_barcode(text,text,text) from public,anon;
grant execute on function public.gs_staff_register_motel_credit_barcode(text,text,text) to authenticated;

create or replace function public.gs_staff_lookup_motel_credit_barcode(
 p_intent_id uuid, p_barcode text)
returns table(identity_status text, account_label text, account_reference text,
              draft_amount_iqd bigint, verification_note text)
language plpgsql security definer set search_path = '' as $$
declare v_d public.gs_motel_food_payment_intent_drafts%rowtype;
 v_f public.gs_motel_food_finance_invoices%rowtype;
 v_a public.gs_motel_credit_barcode_registry%rowtype;
begin
 if auth.uid() is null
 or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false)
 then raise exception 'Finance viewer required'; end if;
 if p_barcode is null or length(btrim(p_barcode)) not between 6 and 128
 then raise exception 'Invalid barcode'; end if;
 select * into v_d from public.gs_motel_food_payment_intent_drafts
 where id=p_intent_id;
 if not found or v_d.method<>'credit' or v_d.status<>'draft'
 then raise exception 'Active credit draft required'; end if;
 select * into v_f from public.gs_motel_food_finance_invoices
 where id=v_d.finance_invoice_id;
 if not found or v_f.payment_status<>'unpaid'
 or v_f.total_iqd is distinct from v_d.amount_iqd
 then raise exception 'Invoice not eligible'; end if;
 select * into v_a from public.gs_motel_credit_barcode_registry
 where barcode_sha256=encode(extensions.digest(btrim(p_barcode),'sha256'),'hex');
 if not found then
  return query select 'not_found'::text,null::text,null::text,v_d.amount_iqd,
   'No registered identity. No credit balance or ownership verified; no debit performed.'::text;
 else
  return query select v_a.account_status,v_a.display_label,v_a.account_reference,
   v_d.amount_iqd,
   'Identity reference only. Verify ownership, available credit, limits and debit authorization separately. No debit performed.'::text;
 end if;
end $$;
revoke all on function public.gs_staff_lookup_motel_credit_barcode(uuid,text) from public,anon;
grant execute on function public.gs_staff_lookup_motel_credit_barcode(uuid,text) to authenticated;
