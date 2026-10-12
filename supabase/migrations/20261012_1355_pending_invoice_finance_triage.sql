-- Upgrade 1355: read-only finance triage for motel Pending Payment invoices.
-- This wrapper does not grant collection rights or modify any payment data.
create or replace function public.gs_pending_payment_motel_invoice_triage(p_invoice_id uuid)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_result jsonb;
  v_reasons jsonb;
  v_count integer;
  v_status text;
  v_action text;
begin
  -- The underlying SECURITY DEFINER diagnostic enforces all three view permissions.
  v_result := public.gs_pending_payment_motel_invoice_integrity(p_invoice_id);
  v_reasons := coalesce(v_result->'review_reason_codes', '[]'::jsonb);
  if jsonb_typeof(v_reasons) <> 'array' then
    raise exception 'Invalid finance review reason payload' using errcode='22023';
  end if;
  v_count := jsonb_array_length(v_reasons);
  v_status := v_result->>'invoice_status';
  v_action := case
    when v_count > 0 then 'REVIEW_INVOICE_AND_SETTLEMENTS'
    when v_status = 'paid_cash' then 'VERIFY_OTHER_CHANNELS_AND_CLOSE_REVIEW'
    else 'VERIFY_ALL_PAYMENT_CHANNELS_BEFORE_COLLECTION'
  end;
  return v_result || jsonb_build_object(
    'triage_action',v_action,
    'triage_severity',case when v_count > 0 then 'review_required' else 'verification_required' end,
    'review_reason_count',v_count,
    'collection_authorized',false,
    'settlement_confirmed',false,
    'triage_read_only',true,
    'warning','Never infer an unpaid collectible balance from invoice-only diagnostics.');
end $$;
revoke all on function public.gs_pending_payment_motel_invoice_triage(uuid) from public,anon;
grant execute on function public.gs_pending_payment_motel_invoice_triage(uuid) to authenticated;
