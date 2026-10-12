-- Upgrade 144: read-only mixed-checkout schema/security diagnostics.
-- Intentionally does not enable payment posting or mixed checkout.
create or replace function public.gs_mixed_checkout_deployment_diagnostics()
returns table(check_name text, passed boolean, details text)
language plpgsql security definer set search_path='' as $$
declare v_type text;v_trigger_count integer;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'aal','')<>'aal2'
   or not public.gs_can_access('invoices_payments','can_edit') then
  raise exception 'MFA and finance edit permission required';
 end if;
 select format_type(a.atttypid,a.atttypmod) into v_type
 from pg_catalog.pg_attribute a
 join pg_catalog.pg_class c on c.oid=a.attrelid
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='gs_unified_payment_ledger'
 and a.attname='amount_iqd' and a.attnum>0 and not a.attisdropped;
 return query select 'ledger_amount_type'::text,
   v_type='bigint',coalesce(v_type,'MISSING');
 select format_type(a.atttypid,a.atttypmod) into v_type
 from pg_catalog.pg_attribute a
 join pg_catalog.pg_class c on c.oid=a.attrelid
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='gs_payment_verification_inbox'
 and a.attname='reported_amount_iqd' and a.attnum>0 and not a.attisdropped;
 return query select 'inbox_amount_type'::text,
   v_type='bigint',coalesce(v_type,'MISSING');
 return query select 'checkout_gate_disabled'::text,
   not exists(select 1 from public.gs_mixed_checkout_feature_gate where enabled),
   'No mixed checkout release may be enabled before provider integration'::text;
 return query select 'client_cannot_post_provider_payment'::text,
   not pg_catalog.has_function_privilege('authenticated',
     'public.gs_post_verified_provider_payment(bigint,uuid)','EXECUTE'),
   'authenticated role must not call trusted posting RPC'::text;
 return query select 'client_cannot_record_verified_event'::text,
   not pg_catalog.has_function_privilege('authenticated',
     'public.gs_record_server_verified_payment_event(bigint,text,text,text,bigint,text)','EXECUTE'),
   'authenticated role must not mark events verified'::text;
 return query select 'mixed_attestation_rls_enabled'::text,
   coalesce((select c.relrowsecurity from pg_catalog.pg_class c
     join pg_catalog.pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public'
      and c.relname='gs_mixed_payment_settlement_attestations'),false),
   'Row level security required'::text;
 return query select 'mixed_attestation_not_client_writable'::text,
   not pg_catalog.has_table_privilege('authenticated',
     'public.gs_mixed_payment_settlement_attestations','INSERT'),
   'No direct client insert privileges'::text;
 select count(*) into v_trigger_count from pg_catalog.pg_trigger t
 join pg_catalog.pg_class c on c.oid=t.tgrelid
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='gs_mixed_payment_settlement_attestations'
 and t.tgname in ('gs_mixed_settlement_immutable',
  'gs_reject_conflicting_mixed_attestation') and t.tgenabled<>'D';
 return query select 'mixed_attestation_triggers'::text,
   v_trigger_count=2,
   format('%s of 2 required triggers enabled',v_trigger_count);
 return query select 'provider_event_uniqueness'::text,
   exists(select 1 from pg_catalog.pg_index ix
     join pg_catalog.pg_class c on c.oid=ix.indrelid
     join pg_catalog.pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relname='gs_payment_verification_inbox'
      and ix.indisunique and ix.indisvalid),
   'At least one valid unique index (manual review of key columns required)'::text;
end; $$;
revoke all on function public.gs_mixed_checkout_deployment_diagnostics()
 from public,anon;
grant execute on function public.gs_mixed_checkout_deployment_diagnostics()
 to authenticated;
