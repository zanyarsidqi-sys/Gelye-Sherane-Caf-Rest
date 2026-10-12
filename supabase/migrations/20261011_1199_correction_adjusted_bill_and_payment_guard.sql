-- Upgrade 1199: approved correction quantities are excluded in a dedicated
-- read-only bill quote. Legacy financial writers remain blocked for affected
-- orders until their payment/settlement implementations are reconciled.
-- Never mutate generated line_total_iqd or erase original kitchen records.

create or replace function public.gs_correction_adjusted_order_bill(p_order_id bigint)
returns table(item_id bigint, product_id bigint, original_quantity integer,
 approved_removed_quantity bigint, payable_quantity bigint,
 unit_price_iqd bigint, payable_line_iqd bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not (
   public.gs_can_access('table_orders','can_view') or
   public.gs_can_access('invoices_payments','can_view') or
   public.gs_can_access('motel_orders','can_view')) then
   raise exception 'Not authorized to view corrected bill';
 end if;
 if not exists(select 1 from public.gs_orders where id=p_order_id) then
   raise exception 'Order not found';
 end if;
 return query
 select i.id,i.product_id,i.quantity,
   coalesce(c.removed,0)::bigint,
   (i.quantity::bigint-coalesce(c.removed,0))::bigint,
   i.unit_price_iqd,
   (i.quantity::bigint-coalesce(c.removed,0))*i.unit_price_iqd
 from public.gs_order_items i
 left join lateral (
   select coalesce(sum(x.requested_quantity),0)::bigint removed
   from public.gs_order_item_corrections x
   where x.item_id=i.id and x.decision='approved'
 ) c on true
 where i.order_id=p_order_id;
end; $$;
revoke all on function public.gs_correction_adjusted_order_bill(bigint) from public,anon;
grant execute on function public.gs_correction_adjusted_order_bill(bigint) to authenticated;

-- Serialize correction approval against the order, prevent cumulative
-- over-correction, and refuse edits once any payment/settlement exists.
create or replace function public.gs_decide_order_item_correction(
 p_correction_id bigint,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v record; v_existing bigint; v_paid boolean;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
 or not public.gs_can_access('table_orders','can_edit')
 or not public.gs_can_access('invoices_payments','can_edit') then
   raise exception 'Finance approval, MFA and edit permissions required';
 end if;
 select c.id,c.order_id,c.item_id,c.requested_quantity,c.decision,
        o.status,i.quantity into v
 from public.gs_order_item_corrections c
 join public.gs_orders o on o.id=c.order_id
 join public.gs_order_items i on i.id=c.item_id
 where c.id=p_correction_id for update of o,i,c;
 if not found then raise exception 'Correction not found'; end if;
 if v.decision <> 'pending' then raise exception 'Correction already decided'; end if;
 if v.status in ('served','cancelled') then
   raise exception 'Terminal order requires separate refund workflow'; end if;
 select exists(select 1 from public.gs_cash_payments where order_id=v.order_id)
   or exists(select 1 from public.gs_unified_payment_ledger where order_id=v.order_id)
   or exists(select 1 from public.gs_cash_only_settlement_attestations where order_id=v.order_id)
   or exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=v.order_id)
 into v_paid;
 if v_paid then raise exception 'Payment or invoice snapshot exists: use refund/credit workflow'; end if;
 select coalesce(sum(requested_quantity),0) into v_existing
 from public.gs_order_item_corrections
 where item_id=v.item_id and decision='approved';
 if p_approve and v_existing+v.requested_quantity>v.quantity then
   raise exception 'Approved correction quantity exceeds ordered quantity'; end if;
 update public.gs_order_item_corrections
 set decision=case when p_approve then 'approved' else 'rejected' end,
 decided_by=auth.uid(),decided_at=transaction_timestamp()
 where id=p_correction_id;
 insert into public.gs_system_audit_events
 (actor_id,section,action,record_id,after_data)
 values(auth.uid(),'table_orders','order_item_correction_decided',
 p_correction_id::text,jsonb_build_object('order_id',v.order_id,
 'item_id',v.item_id,'quantity',v.requested_quantity,'approved',p_approve));
end; $$;
revoke all on function public.gs_decide_order_item_correction(bigint,boolean) from public,anon;
grant execute on function public.gs_decide_order_item_correction(bigint,boolean) to authenticated;

-- Legacy payment code still sums the original generated line_total_iqd.
-- Fail closed instead of overcharging customers until financial writer
-- functions are updated to use corrected payable amounts.
create or replace function public.gs_guard_uncorrected_payment_posting()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.gs_order_item_corrections c
   where c.order_id=new.order_id and c.decision='approved') then
   raise exception 'Approved item correction: use corrected financial posting workflow';
 end if;
 return new;
end; $$;
drop trigger if exists gs_guard_correction_legacy_cash on public.gs_cash_payments;
create trigger gs_guard_correction_legacy_cash before insert or update
 on public.gs_cash_payments for each row
 execute function public.gs_guard_uncorrected_payment_posting();
drop trigger if exists gs_guard_correction_legacy_ledger on public.gs_unified_payment_ledger;
create trigger gs_guard_correction_legacy_ledger before insert or update
 on public.gs_unified_payment_ledger for each row
 execute function public.gs_guard_uncorrected_payment_posting();
revoke all on function public.gs_guard_uncorrected_payment_posting() from public,anon,authenticated;
