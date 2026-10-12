-- Upgrade 1152: execute ONLY on an isolated staging database with a disposable order.
-- Requires psql variables: -v test_order_id=123 -v test_employee_uuid=...
-- A valid employee with kitchen can_edit and an existing NEW order with at least
-- one valid item are required. The entire test rolls back.
-- DO NOT run in production: RPCs can have external side effects.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'test_employee_uuid', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('gs_test.order_id', :'test_order_id', true);
DO $$
DECLARE
  v_id bigint := current_setting('gs_test.order_id')::bigint;
  v_state text;
BEGIN
  IF NOT public.gs_can_access('kitchen','can_edit') THEN
    RAISE EXCEPTION 'Fixture employee lacks kitchen edit permission';
  END IF;
  SELECT status INTO v_state FROM public.gs_orders WHERE id = v_id FOR UPDATE;
  IF v_state IS DISTINCT FROM 'new' THEN
    RAISE EXCEPTION 'Fixture order must start NEW; found %', v_state;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.gs_order_items WHERE order_id = v_id) THEN
    RAISE EXCEPTION 'Fixture order must contain valid items';
  END IF;
  PERFORM public.gs_update_kitchen_status(v_id, 'preparing');
  PERFORM public.gs_update_kitchen_status(v_id, 'ready');
  PERFORM public.gs_update_kitchen_status(v_id, 'served');
  SELECT status INTO v_state FROM public.gs_orders WHERE id = v_id;
  IF v_state <> 'served' THEN
    RAISE EXCEPTION 'Kitchen handover did not persist inside transaction';
  END IF;
  BEGIN
    PERFORM public.gs_update_kitchen_status(v_id, 'preparing');
    RAISE EXCEPTION 'Regression: served order was reopened';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Regression: served order was reopened' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.gs_order_items WHERE order_id = v_id;
    RAISE EXCEPTION 'Regression: served items were deleted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'Regression: served items were deleted' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
-- PASS means transaction assertions completed and changes were rolled back.
