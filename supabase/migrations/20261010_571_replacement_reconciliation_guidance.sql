-- Upgrade 571: classify reconciliation evidence without claiming financial or kitchen completion.
-- Keep the original receipt/revision checks from 570; add a separate, read-only
-- interpretation so older clients retain their existing response contract.
create or replace function public.gs_table_replacement_reconciliation_guidance(p_request_id uuid)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare v jsonb; v_state text; v_message text;
begin
  v := public.gs_table_replacement_reconciliation(p_request_id);
  if v->>'status' <> 'committed' then
    return v || jsonb_build_object('review_state','unconfirmed',
      'staff_guidance','No committed receipt is visible. Do not retry automatically; inspect the order and kitchen history.');
  end if;
  if coalesce((v->>'revision_found')::boolean,false) is false
     or coalesce((v->>'revision_matches_receipt')::boolean,false) is false then
    v_state := 'revision_investigation';
    v_message := 'Replacement committed, but its revision evidence is missing or inconsistent. Stop further edits and contact a manager.';
  elsif coalesce((v->>'kitchen_dispatch_recorded')::boolean,false) is false then
    v_state := 'dispatch_investigation';
    v_message := 'Replacement committed, but no kitchen dispatch record was found. Check kitchen revision delivery before continuing.';
  elsif coalesce((v->>'current_item_matches_receipt')::boolean,false) is false then
    v_state := 'item_changed_since_receipt';
    v_message := 'Replacement committed; the item differs from the receipt. Review later edits and revision history before deciding whether action is needed.';
  else
    v_state := 'recorded_evidence_consistent';
    v_message := 'Receipt, revision, dispatch record, and current item agree. Kitchen acknowledgment and financial settlement remain unverified.';
  end if;
  return v || jsonb_build_object('review_state',v_state,'staff_guidance',v_message,
    'kitchen_acknowledged',null,'financially_reconciled',null);
end $$;
revoke all on function public.gs_table_replacement_reconciliation_guidance(uuid) from public,anon,authenticated;
grant execute on function public.gs_table_replacement_reconciliation_guidance(uuid) to authenticated;
