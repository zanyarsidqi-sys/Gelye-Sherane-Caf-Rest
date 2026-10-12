-- Upgrade 142: explicit schema compatibility preflight.
-- This migration makes no financial writes and never enables checkout.
-- Run against staging before proceeding with live payment workflows.
do $$
declare r record;v_missing text;
begin
 for r in
  select expected.table_name,expected.column_name
  from (values
    ('gs_orders','id'),
    ('gs_orders','table_visit_id'),
    ('gs_orders','status'),
    ('gs_table_visits','id'),
    ('gs_table_visits','table_id'),
    ('gs_table_visits','status'),
    ('gs_table_visits','closed_at'),
    ('gs_table_visits','closed_by'),
    ('gs_cafe_tables','id'),
    ('gs_cafe_tables','occupied'),
    ('gs_cafe_tables','guests'),
    ('gs_cafe_tables','tourism_mode'),
    ('gs_cafe_tables','cleaning_needed'),
    ('gs_cafe_tables','guests_departed_at'),
    ('gs_cafe_tables','updated_at'),
    ('gs_cafe_tables','updated_by'),
    ('gs_order_items','id'),
    ('gs_order_items','order_id'),
    ('gs_order_items','line_total_iqd'),
    ('gs_cash_payments','id'),
    ('gs_cash_payments','order_id'),
    ('gs_cash_payments','amount_iqd'),
    ('gs_cash_payments','collected_by'),
    ('gs_external_payment_evidence','id'),
    ('gs_external_payment_evidence','order_id'),
    ('gs_external_payment_evidence','method'),
    ('gs_external_payment_evidence','external_reference'),
    ('gs_external_payment_evidence','amount_iqd'),
    ('gs_payment_verification_inbox','id'),
    ('gs_payment_verification_inbox','evidence_id'),
    ('gs_payment_verification_inbox','provider'),
    ('gs_payment_verification_inbox','provider_event_id'),
    ('gs_payment_verification_inbox','provider_reference'),
    ('gs_payment_verification_inbox','reported_amount_iqd'),
    ('gs_payment_verification_inbox','reported_currency'),
    ('gs_payment_verification_inbox','intake_status'),
    ('gs_payment_verification_inbox','verified_at'),
    ('gs_unified_payment_ledger','id'),
    ('gs_unified_payment_ledger','order_id'),
    ('gs_unified_payment_ledger','entry_type'),
    ('gs_unified_payment_ledger','amount_iqd'),
    ('gs_unified_payment_ledger','direction'),
    ('gs_unified_payment_ledger','source_system'),
    ('gs_unified_payment_ledger','source_reference'),
    ('gs_unified_payment_ledger','verified_at'),
    ('gs_unified_payment_ledger','posted_at'),
    ('gs_unified_payment_ledger','posted_by'),
    ('gs_cash_only_settlement_attestations','order_id'),
    ('gs_cash_only_settlement_attestations','table_visit_id'),
    ('gs_mixed_payment_settlement_attestations','order_id'),
    ('gs_mixed_payment_settlement_attestations','table_visit_id'),
    ('gs_mixed_payment_settlement_attestations','order_total_iqd'),
    ('gs_mixed_payment_settlement_attestations','cash_iqd'),
    ('gs_mixed_payment_settlement_attestations','verified_provider_iqd'),
    ('gs_mixed_payment_settlement_attestations','provider_payment_count'),
    ('gs_cash_ledger_reconciliation_links','ledger_entry_id'),
    ('gs_cash_ledger_reconciliation_links','legacy_cash_id'),
    ('gs_mixed_checkout_feature_gate','singleton'),
    ('gs_mixed_checkout_feature_gate','enabled')
  ) as expected(table_name,column_name)
  where not exists (
    select 1 from information_schema.columns c
    where c.table_schema='public'
      and c.table_name=expected.table_name
      and c.column_name=expected.column_name)
 loop
  v_missing:=concat_ws(E'\n',v_missing,
    format('public.%I.%I',r.table_name,r.column_name));
 end loop;
 if v_missing is not null then
  raise exception 'Checkout schema incompatibility: %',v_missing;
 end if;
 if to_regprocedure('public.gs_visit_physical_checkout_status(bigint)') is null
   or to_regprocedure('public.gs_can_access(text,text)') is null
   or to_regprocedure('public.gs_release_mixed_payment_table_visit(bigint)') is null
 then raise exception 'Required checkout function missing or signature differs';
 end if;
 if exists(select 1 from public.gs_mixed_checkout_feature_gate
   where enabled) then
  raise exception 'Mixed checkout must remain disabled during compatibility review';
 end if;
end $$;
