\
-- Upgrade 1153: staging-only negative authorization transaction test.
-- psql -v test_order_id=123 -v denied_employee_uuid=... -f ...
-- Fixture must be an authenticated employee WITHOUT kitchen can_edit.
-- This script makes no durable changes and must never be used on production.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'denied_employee_uuid', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('gs_test.order_id', :'test_order_id', true);
DO $$
DECLARE
  v_id bigint := current_setting('gs_test.order_id')::bigint;
  v_before text;
  v_after text;
  v_denied boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'JWT simulation failed: auth.uid() is null';
  END IF;
  IF public.gs_can_access('kitchen','can_edit') THEN
    RAISE EXCEPTION 'Invalid negative fixture: employee CAN edit Kitchen';
  END IF;
  SELECT status INTO v_before FROM public.gs_orders WHERE id = v_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Test order % does not exist', v_id;
  END IF;
  BEGIN
    PERFORM public.gs_update_kitchen_status(v_id, 'preparing');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%Not authorized to update kitchen orders%' THEN
      v_denied := true;
    ELSE
      RAISE EXCEPTION 'Unexpected error (not an authorization denial): %', SQLERRM;
    END IF;
  END;
  IF NOT v_denied THEN
    RAISE EXCEPTION 'SECURITY REGRESSION: unauthorized kitchen status RPC succeeded';
  END IF;
  SELECT status INTO v_after FROM public.gs_orders WHERE id = v_id;
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'SECURITY REGRESSION: order changed despite denial';
  END IF;
END $$;
ROLLBACK;
-- PASS requires explicit expected authorization denial and unchanged order state.
