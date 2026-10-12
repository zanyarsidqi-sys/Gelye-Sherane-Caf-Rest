-- Upgrade 247: fix reconciliation contract and expose conservative payment-source audit.
-- No cash collection, credit debit, or paid-state mutation is authorized.
create or replace function public.gs_prepare_locked_discount_payment(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_snapshot public.gs_admin_discount_invoice_snapshots%rowtype;
 v_intent public.gs_locked_discount_payment_intents%rowtype;
 v_recon jsonb;
begin
 if auth.uid() is null or not exists
   (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id<=0 then raise exception 'Invalid order'; end if;
 -- Serialize all requests per order; order guards already require this lock.
 perform 1 from public.gs_orders where id=p_order_id for update;
 if not found then raise exception 'Order not found'; end if;
 select * into v_snapshot from public.gs_admin_discount_invoice_snapshots
 where order_id=p_order_id;
 if not found then raise exception 'Lock an approved discounted invoice first'; end if;
 -- Existing intent is idempotent; no external payment action is performed.
 select * into v_intent from public.gs_locked_discount_payment_intents
 where snapshot_id=v_snapshot.id;
 if not found then
   -- Conservative diagnostic; any unknown or recorded payment must block preparation.
   v_recon := public.gs_admin_discount_payment_reconciliation(p_order_id);
   if coalesce(v_recon->>'eligibility','') <> 'provisional_no_known_payment'
      or coalesce((v_recon->>'read_only')::boolean,false) is not true
      or coalesce((v_recon->>'final_settlement_authorized')::boolean,true) is not false then
     raise exception 'Payment reconciliation not cleared: %',v_recon->>'eligibility';
   end if;
   insert into public.gs_locked_discount_payment_intents
    (snapshot_id,order_id,amount_due_iqd,created_by)
   values (v_snapshot.id,p_order_id,v_snapshot.amount_due_iqd,auth.uid())
   returning * into v_intent;
 end if;
 return jsonb_build_object('intent_id',v_intent.id,'snapshot_id',v_intent.snapshot_id,
  'order_id',v_intent.order_id,'amount_due_iqd',v_intent.amount_due_iqd,
  'status',v_intent.status,'payment_authorized',false,'money_moved',false);
end; $$;

revoke all on function public.gs_prepare_locked_discount_payment(bigint) from public,anon;
grant execute on function public.gs_prepare_locked_discount_payment(bigint) to authenticated;

create or replace function public.gs_locked_discount_payment_source_audit(p_order_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 v_recon jsonb;
 v_intent public.gs_locked_discount_payment_intents%rowtype;
 v_snapshot public.gs_admin_discount_invoice_snapshots%rowtype;
 v_sources jsonb := '[]'::jsonb;
 v_relation text;
 v_columns jsonb;
 v_exists boolean;
begin
 if auth.uid() is null or not exists
  (select 1 from public.gs_cafe_discount_admins where user_id=auth.uid())
 then raise exception 'Admin authorization required'; end if;
 if p_order_id is null or p_order_id <= 0 then raise exception 'Invalid order'; end if;
 v_recon := public.gs_admin_discount_payment_reconciliation(p_order_id);
 select * into v_snapshot from public.gs_admin_discount_invoice_snapshots where order_id=p_order_id;
 select * into v_intent from public.gs_locked_discount_payment_intents where order_id=p_order_id;
 foreach v_relation in array array[
  'gs_cash_payments','gs_cash_only_settlement_attestations',
  'gs_unified_payment_ledger','gs_payment_ledger','gs_credit_transactions',
  'gs_mixed_payment_finance_attestations','gs_item_payment_allocations',
  'gs_order_payment_confirmations','gs_external_payment_evidence'
 ] loop
  v_exists := to_regclass('public.' || v_relation) is not null;
  if v_exists then
   select coalesce(jsonb_agg(jsonb_build_object('name',column_name,'type',data_type)
          order by ordinal_position),'[]'::jsonb)
   into v_columns from information_schema.columns
   where table_schema='public' and table_name=v_relation;
  else v_columns := '[]'::jsonb; end if;
  v_sources := v_sources || jsonb_build_array(jsonb_build_object(
    'relation',v_relation,'exists',v_exists,'columns',v_columns,
    'has_order_id',v_columns @> '[{"name":"order_id"}]'::jsonb));
 end loop;
 return jsonb_build_object(
  'order_id',p_order_id,'reconciliation',v_recon,
  'locked_snapshot_exists',v_snapshot.id is not null,
  'locked_amount_due_iqd',v_snapshot.amount_due_iqd,
  'payment_intent_exists',v_intent.id is not null,
  'payment_intent_status',v_intent.status,
  'sources',v_sources,'payment_capture_enabled',false,
  'live_provider_verification_complete',false,'read_only',true);
end; $$;
revoke all on function public.gs_locked_discount_payment_source_audit(bigint) from public,anon;
grant execute on function public.gs_locked_discount_payment_source_audit(bigint) to authenticated;
