-- Upgrade 382: read-only finance intake integrity verification. No invoice/payment posting.
create or replace function public.gs_staff_motel_food_intake_integrity(p_food_invoice_id uuid)
returns table(intake_id uuid, intake_status text, issue_count integer, details text, intake_total_iqd bigint, current_total_iqd bigint)
language plpgsql security definer set search_path = '' as $$
declare v_intake public.gs_motel_food_unified_invoice_intake%rowtype;
 v_header public.gs_motel_food_invoice_register%rowtype;
 v_att public.gs_motel_food_finance_attestations%rowtype;
 v_state record; v_issues text[] := array[]::text[];
begin
 if auth.uid() is null or not coalesce(public.gs_can_access('motel_orders','can_view'),false)
 or not coalesce(public.gs_can_access('invoices_payments','can_view'),false) then
  raise exception 'Motel and invoice viewing permissions required';
 end if;
 select * into v_header from public.gs_motel_food_invoice_register where id=p_food_invoice_id;
 if not found then raise exception 'Food invoice register not found'; end if;
 select * into v_intake from public.gs_motel_food_unified_invoice_intake where food_invoice_id=p_food_invoice_id;
 if not found then
  return query select null::uuid,'missing'::text,1,'No finance intake draft exists'::text,null::bigint,v_header.total_iqd;
  return;
 end if;
 select * into v_att from public.gs_motel_food_finance_attestations where id=v_intake.attestation_id;
 if not found then v_issues:=array_append(v_issues,'Attestation record missing');
 else
  if v_att.food_invoice_id is distinct from p_food_invoice_id then v_issues:=array_append(v_issues,'Attestation references another invoice'); end if;
  if v_intake.source_fingerprint is distinct from v_att.source_fingerprint then v_issues:=array_append(v_issues,'Attestation fingerprint changed'); end if;
 end if;
 if v_intake.guest_session_id is distinct from v_header.guest_session_id or v_intake.room_id is distinct from v_header.room_id then
  v_issues:=array_append(v_issues,'Guest stay or room mismatch'); end if;
 if v_intake.total_iqd is distinct from v_header.total_iqd or v_intake.source_count is distinct from v_header.source_count then
  v_issues:=array_append(v_issues,'Invoice total or order count changed'); end if;
 select * into v_state from public.gs_staff_motel_food_attestation_status(p_food_invoice_id);
 if v_state.attestation_status is distinct from 'valid' then v_issues:=array_append(v_issues,'Attestation no longer valid'); end if;
 return query select v_intake.id,case when cardinality(v_issues)=0 then 'verified' else 'stale' end,
 cardinality(v_issues),case when cardinality(v_issues)=0 then 'Source and attestation checks passed' else array_to_string(v_issues,'; ') end,
 v_intake.total_iqd,v_header.total_iqd;
end; $$;
revoke all on function public.gs_staff_motel_food_intake_integrity(uuid) from public,anon;
grant execute on function public.gs_staff_motel_food_intake_integrity(uuid) to authenticated;
