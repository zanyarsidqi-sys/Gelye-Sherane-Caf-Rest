-- Upgrade 380: read-only finance attestation status. Never creates invoices/payments.
create or replace function public.gs_staff_motel_food_attestation_status(p_invoice_id uuid)
returns table(attestation_status text, attested_at timestamptz, attested_by uuid,
 attested_total_iqd bigint, current_total_iqd bigint, attested_source_count integer,
 current_source_count integer)
language plpgsql security definer set search_path = '' as $$
declare v_header public.gs_motel_food_invoice_register%rowtype;
 v_att public.gs_motel_food_finance_attestations%rowtype;
 v_fingerprint text; v_readiness record;
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and invoice viewing permissions required';
 end if;
 select * into v_header from public.gs_motel_food_invoice_register where id=p_invoice_id;
 if not found then raise exception 'Food invoice register not found'; end if;
 select * into v_att from public.gs_motel_food_finance_attestations where food_invoice_id=p_invoice_id;
 select md5(coalesce(string_agg(l.source_order_id::text||':'||l.source_ledger_id::text||':'||
 l.reservation_id::text||':'||l.amount_iqd::text,'|' order by l.source_order_id),''))
 into v_fingerprint from public.gs_motel_food_invoice_register_lines l where l.invoice_id=p_invoice_id;
 select * into v_readiness from public.gs_staff_motel_food_invoice_readiness(p_invoice_id);
 return query select
 case when v_att.id is null then 'not_attested'::text
 when v_readiness.readiness_status <> 'source_verified' or
 v_att.source_fingerprint is distinct from v_fingerprint or
 v_att.source_count is distinct from v_header.source_count or
 v_att.total_iqd is distinct from v_header.total_iqd then 'stale'::text
 else 'valid'::text end,
 v_att.attested_at,v_att.attested_by,v_att.total_iqd,v_header.total_iqd,
 v_att.source_count,v_header.source_count;
end; $$;
revoke all on function public.gs_staff_motel_food_attestation_status(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_attestation_status(uuid) to authenticated;
