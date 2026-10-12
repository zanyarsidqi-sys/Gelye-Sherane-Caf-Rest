-- Upgrade 86: read-only reversal exposure diagnostics (DRAFT).
-- Does NOT verify provider refunds, authorize posting, or certify settlement.
create or replace function public.gs_dashboard_reversal_exposure(p_order_id bigint)
returns table(
 original_ledger_entry_id bigint, original_amount_iqd bigint,
 reversed_amount_iqd bigint, remaining_reversible_iqd bigint,
 reversal_count bigint, anomaly text, refund_execution_permitted boolean
)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
  public.gs_can_access('invoices_payments','can_view') or
  public.gs_can_access('payments_management','can_view')
 ) then raise exception 'Financial reversal inspection denied'; end if;
 if p_order_id is null or not exists (
  select 1 from public.gs_orders where id=p_order_id
 ) then raise exception 'Order not found'; end if;
 return query
 select l.id,l.amount_iqd,
  coalesce(r.total_iqd,0)::bigint,
  greatest(0,l.amount_iqd-coalesce(r.total_iqd,0))::bigint,
  coalesce(r.n,0)::bigint,
  case
   when coalesce(r.total_iqd,0)>l.amount_iqd then 'over_reversed'
   when l.direction<>'credit' then 'not_original_credit'
   when l.entry_type in ('refund','reversal') then 'nested_reversal_invalid'
   when coalesce(r.n,0)>0 then 'reversal_entries_exist_not_provider_verified'
   else 'no_reversals_recorded_not_payment_verified'
  end::text,
  false
 from public.gs_unified_payment_ledger l
 left join lateral (
  select coalesce(sum(x.amount_iqd),0)::bigint as total_iqd,
   count(*)::bigint as n
  from public.gs_unified_payment_ledger x
  where x.original_entry_id=l.id
   and x.entry_type in ('refund','reversal') and x.direction='debit'
 ) r on true
 where l.order_id=p_order_id and l.direction='credit'
 order by l.id;
end; $$;
revoke all on function public.gs_dashboard_reversal_exposure(bigint)
 from public,anon;
grant execute on function public.gs_dashboard_reversal_exposure(bigint)
 to authenticated;
-- All results are diagnostic; refund_execution_permitted is always false.
