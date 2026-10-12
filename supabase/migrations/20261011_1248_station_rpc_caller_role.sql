-- Upgrade 1248: repair SECURITY DEFINER caller identity for station device RPCs.
-- CURRENT_USER reflects the function owner, not the invoking API role.
-- The service_role credential MUST remain on the Edge Function server.
DO $migration$
DECLARE v_oid oid; v_def text; v_fixed text;
BEGIN
 FOR v_oid IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN (
  'gs_1223_device_login','gs_1223_device_heartbeat','gs_1226_device_logout',
  'gs_1227_device_claim_print','gs_1227_device_ack_print',
  'gs_1230_resolve_station_ticket')
 LOOP
  SELECT pg_get_functiondef(v_oid) INTO v_def;
  IF v_def ~* 'current_user' THEN
   IF v_def !~* 'current_user[[:space:]]*<>[[:space:]]*''service_role''' THEN
    RAISE EXCEPTION 'Unexpected caller-role check in %',v_oid::regprocedure;
   END IF;
   v_fixed := regexp_replace(v_def,
    'current_user[[:space:]]*<>[[:space:]]*''service_role''',
    'auth.role() IS DISTINCT FROM ''service_role''','gi');
   EXECUTE v_fixed;
  END IF;
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated',v_oid::regprocedure);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',v_oid::regprocedure);
 END LOOP;
END $migration$;
