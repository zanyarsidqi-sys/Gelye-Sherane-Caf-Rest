-- Upgrade 1200: corrected pre-payment invoice, atomic cash collection,
-- and controlled replacement item. Existing legacy financial paths stay guarded.
-- This is NOT a universal card/credit/discount/motel settlement integration.
create or replace function public.gs_corrected_invoice_quote(p_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_total bigint; v_original bigint; v_paid bigint; v_pending bigint; v_order public.gs_orders%rowtype;
begin
 if auth.uid() is null or not (public.gs_can_access('table_orders','can_view')
 or public.gs_can_access('invoices_payments','can_view')) then
 raise exception 'Invoice view permission required'; end if;
 select * into v_order from public.gs_orders where id=p_order_id;
 if not found then raise exception 'Order not found'; end if;
 select coalesce(sum(i.line_total_iqd),0) into v_original from public.gs_order_items i where i.order_id=p_order_id;
 select coalesce(sum((i.quantity::bigint-coalesce(c.removed,0))*i.unit_price_iqd),0)
 into v_total from public.gs_order_items i left join lateral (
 select coalesce(sum(x.requested_quantity),0)::bigint removed
 from public.gs_order_item_corrections x where x.item_id=i.id and x.decision='approved'
 ) c on true where i.order_id=p_order_id;
 select count(*) into v_pending from public.gs_order_item_corrections
 where order_id=p_order_id and decision='pending';
 select coalesce(sum(amount_iqd),0) into v_paid from public.gs_cash_payments where order_id=p_order_id;
 return jsonb_build_object('order_id',p_order_id,'original_total_iqd',v_original,
 'approved_removed_iqd',v_original-v_total,'corrected_total_iqd',v_total,
 'cash_paid_iqd',v_paid,'cash_remaining_iqd',greatest(v_total-v_paid,0),
 'pending_corrections',v_pending,'ready_for_cash',v_pending=0 and v_total>v_paid
 and v_order.status not in ('cancelled','served') and not v_order.is_motel);
end; $$;
revoke all on function public.gs_corrected_invoice_quote(bigint) from public,anon;
grant execute on function public.gs_corrected_invoice_quote(bigint) to authenticated;

-- Replacement item must be a real order line, priced on the server.
-- Link it once to the approved correction and never copy client-provided prices.
create or replace function public.gs_add_approved_correction_replacement(p_correction_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare v record; v_product public.gs_menu_products%rowtype; v_id bigint; v_price bigint;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','') <> 'aal2'
 or not public.gs_can_access('table_orders','can_edit')
 or not public.gs_can_access('invoices_payments','can_edit') then
 raise exception 'Authorized manager with MFA required'; end if;
 select c.id,c.order_id,c.replacement_product_id,c.replacement_item_id,c.requested_quantity,
 c.decision,o.tourism_mode,o.is_motel,o.status into v
 from public.gs_order_item_corrections c join public.gs_orders o on o.id=c.order_id
 where c.id=p_correction_id for update of o,c;
 if not found or v.decision <> 'approved' or v.replacement_product_id is null then
 raise exception 'Approved correction with replacement product required'; end if;
 if v.replacement_item_id is not null then return v.replacement_item_id; end if;
 if v.is_motel or v.status in ('cancelled','served') then
 raise exception 'Motel or terminal replacement requires separate workflow'; end if;
 if exists(select 1 from public.gs_cash_payments where order_id=v.order_id)
 or exists(select 1 from public.gs_unified_payment_ledger where order_id=v.order_id)
 or exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=v.order_id)
 or exists(select 1 from public.gs_cash_only_settlement_attestations where order_id=v.order_id) then
 raise exception 'Existing financial activity: manual refund/reconciliation required'; end if;
 select * into v_product from public.gs_menu_products where id=v.replacement_product_id and is_active for share;
 if not found then raise exception 'Replacement product unavailable'; end if;
 v_price := case when v.tourism_mode then v_product.tourism_price_iqd else v_product.normal_price_iqd end;
 insert into public.gs_order_items(order_id,product_id,quantity,unit_price_iqd)
 values(v.order_id,v_product.id,v.requested_quantity,v_price) returning id into v_id;
 update public.gs_order_item_corrections set replacement_item_id=v_id where id=p_correction_id;
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'table_orders','correction_replacement_added',p_correction_id::text,
 jsonb_build_object('order_id',v.order_id,'replacement_item_id',v_id,'unit_price_iqd',v_price));
 return v_id;
end; $$;
revoke all on function public.gs_add_approved_correction_replacement(bigint) from public,anon;
grant execute on function public.gs_add_approved_correction_replacement(bigint) to authenticated;

-- Preserve the legacy correction guard for every payment path except a narrowly
-- scoped, audited corrected-cash writer. Transaction-local flag is NOT trusted:
-- the trigger also verifies caller identity, exact amount, order lock and quote.
create or replace function public.gs_guard_uncorrected_payment_posting()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.gs_order_item_corrections c
 where c.order_id=new.order_id and c.decision='approved') then
   if tg_table_name='gs_cash_payments' and tg_op='INSERT'
   and current_setting('gs.corrected_cash_writer',true)='enabled'
   and auth.uid() is not null and new.collected_by=auth.uid() then
     return new;
   end if;
   raise exception 'Approved item correction: use corrected financial posting workflow';
 end if;
 return new;
end; $$;
revoke all on function public.gs_guard_uncorrected_payment_posting() from public,anon,authenticated;

create or replace function public.gs_record_corrected_cash_payment(
 p_order_id bigint,p_amount_iqd bigint,p_reference uuid)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_order public.gs_orders%rowtype; v_due bigint; v_paid bigint;
 v_pending bigint; v_existing public.gs_cash_payments%rowtype; v_id bigint;
begin
 if auth.uid() is null or not public.gs_can_access('invoices_payments','can_create') then
 raise exception 'Cash collection permission required'; end if;
 if p_order_id is null or p_amount_iqd is null or p_amount_iqd<=0 or p_reference is null then
 raise exception 'Invalid payment request'; end if;
 select * into v_order from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 if v_order.is_motel or v_order.status in ('cancelled','served') then
 raise exception 'Unsupported or terminal order'; end if;
 if exists(select 1 from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id)
 or exists(select 1 from public.gs_unified_payment_ledger where order_id=p_order_id)
 or exists(select 1 from public.gs_cash_only_settlement_attestations where order_id=p_order_id) then
 raise exception 'Financial source requires separate reconciliation'; end if;
 select * into v_existing from public.gs_cash_payments where reference=p_reference;
 if found then
   if v_existing.order_id=p_order_id and v_existing.amount_iqd=p_amount_iqd then return v_existing.id; end if;
   raise exception 'Payment reference reused with different amount';
 end if;
 select count(*) into v_pending from public.gs_order_item_corrections
 where order_id=p_order_id and decision='pending';
 if v_pending>0 then raise exception 'Resolve pending corrections before payment'; end if;
 select coalesce(sum((i.quantity::bigint-coalesce(c.removed,0))*i.unit_price_iqd),0)
 into v_due from public.gs_order_items i left join lateral (
 select coalesce(sum(x.requested_quantity),0)::bigint removed
 from public.gs_order_item_corrections x where x.item_id=i.id and x.decision='approved'
 ) c on true where i.order_id=p_order_id;
 select coalesce(sum(amount_iqd),0) into v_paid from public.gs_cash_payments where order_id=p_order_id;
 if v_due<=0 or p_amount_iqd>v_due-v_paid then
 raise exception 'Payment exceeds corrected outstanding balance'; end if;
 perform set_config('gs.corrected_cash_writer','enabled',true);
 insert into public.gs_cash_payments(order_id,amount_iqd,reference,collected_by)
 values(p_order_id,p_amount_iqd,p_reference,auth.uid()) returning id into v_id;
 perform set_config('gs.corrected_cash_writer','disabled',true);
 insert into public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 values(auth.uid(),'invoices_payments','corrected_cash_payment',v_id::text,
 jsonb_build_object('order_id',p_order_id,'amount_iqd',p_amount_iqd,'corrected_due_iqd',v_due));
 return v_id;
end; $$;
revoke all on function public.gs_record_corrected_cash_payment(bigint,bigint,uuid) from public,anon;
grant execute on function public.gs_record_corrected_cash_payment(bigint,bigint,uuid) to authenticated;
