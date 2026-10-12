-- Fail before index creation with actionable diagnostics; never discard or auto-approve evidence.
do $$
declare v_order bigint; v_invoice uuid;
begin
 select cafe_order_id into v_order from public.gs_financial_crosswalk_evidence
 where review_state <> 'rejected' group by cafe_order_id having count(*) > 1 limit 1;
 if v_order is not null then
  raise exception 'Crosswalk migration blocked: multiple active candidates for cafe order %. Resolve evidence under authorized review before retrying.',v_order using errcode='23505';
 end if;
 select motel_invoice_id into v_invoice from public.gs_financial_crosswalk_evidence
 where review_state <> 'rejected' group by motel_invoice_id having count(*) > 1 limit 1;
 if v_invoice is not null then
  raise exception 'Crosswalk migration blocked: multiple active candidates for motel invoice %. Resolve evidence under authorized review before retrying.',v_invoice using errcode='23505';
 end if;
end $$;

