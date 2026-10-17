BEGIN;
DO $setup$
DECLARE u uuid:=gen_random_uuid(); t uuid; m uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(u);
 INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'admin');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 INSERT INTO public.cafe_dining_tables(name,created_by,updated_by) VALUES('Rollback test',u,u) RETURNING id INTO t;
 SELECT id INTO m FROM public.save_cafe_menu_item(NULL,'Verification meal','Test','',2500,true);
 PERFORM set_config('test.table',t::text,true);PERFORM set_config('test.product',m::text,true);
END;$setup$;
SET LOCAL ROLE authenticated;
DO $test$
DECLARE src text; req uuid; p_req uuid; result jsonb; retry jsonb; pay uuid; refund uuid; products jsonb:=jsonb_build_array(jsonb_build_object('item_id',current_setting('test.product'),'quantity',2)); count_rows int;
BEGIN
 FOREACH src IN ARRAY ARRAY['table','motel','online','walk_in'] LOOP
  req:=gen_random_uuid();
  result:=public.submit_cafe_staff_order(req,src,CASE WHEN src='table' THEN current_setting('test.table')::uuid END,'Ref 12',products,'No salt');
  IF (result->>'total_iqd')::bigint<>5000 OR jsonb_array_length(result->'items')<>1 THEN RAISE EXCEPTION 'Wrong total or lines'; END IF;
  retry:=public.submit_cafe_staff_order(req,src,CASE WHEN src='table' THEN current_setting('test.table')::uuid END,'Ref 12',products,'No salt');
  IF retry->>'id'<>result->>'id' THEN RAISE EXCEPTION 'Duplicate retry'; END IF;
  BEGIN
   PERFORM public.submit_cafe_staff_order(req,src,CASE WHEN src='table' THEN current_setting('test.table')::uuid END,'Ref 12',products,'Changed');
   RAISE EXCEPTION 'Changed retry accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  SELECT count(*) INTO count_rows FROM public.list_cafe_staff_orders(src,true);
  IF count_rows<1 THEN RAISE EXCEPTION 'Missing order in source list'; END IF;
  p_req:=gen_random_uuid();
  pay:=public.capture_cafe_payment(p_req,(result->>'id')::uuid,2000,'cash','');
  IF public.capture_cafe_payment(p_req,(result->>'id')::uuid,2000,'cash','')<>pay THEN RAISE EXCEPTION 'Duplicate payment'; END IF;
  BEGIN
   PERFORM public.capture_cafe_payment(gen_random_uuid(),(result->>'id')::uuid,4000,'cash','');
   RAISE EXCEPTION 'Overpayment accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
   PERFORM public.transition_cafe_order((result->>'id')::uuid,'cancelled');
   RAISE EXCEPTION 'Paid cancellation accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
   PERFORM public.capture_cafe_payment(gen_random_uuid(),(result->>'id')::uuid,3000,'manual_card','');
   RAISE EXCEPTION 'Card reference not required';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM public.capture_cafe_payment(gen_random_uuid(),(result->>'id')::uuid,3000,'manual_card','Terminal 123');
  p_req:=gen_random_uuid();refund:=public.refund_cafe_payment(p_req,pay,1000,'Test return');
  IF public.refund_cafe_payment(p_req,pay,1000,'Test return')<>refund THEN RAISE EXCEPTION 'Duplicate refund'; END IF;
  BEGIN
   PERFORM public.refund_cafe_payment(gen_random_uuid(),pay,2000,'Test return');
   RAISE EXCEPTION 'Excess refund accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
   PERFORM public.transition_cafe_order((result->>'id')::uuid,'served');
   RAISE EXCEPTION 'Skipped status accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM public.transition_cafe_order((result->>'id')::uuid,'preparing');
  PERFORM public.transition_cafe_order((result->>'id')::uuid,'ready');
  PERFORM public.transition_cafe_order((result->>'id')::uuid,'served');
 END LOOP;
 PERFORM public.list_cafe_menu_items();
 PERFORM public.list_cafe_payment_balances();
 BEGIN
  PERFORM 1 FROM public.cafe_payments;
  RAISE EXCEPTION 'Direct payment access allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN
  PERFORM public.list_cafe_payment_balances();
  RAISE EXCEPTION 'Anonymous payment access allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.list_cafe_staff_orders('motel',true);
  RAISE EXCEPTION 'Anonymous order access allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$test$;
RESET ROLE;
DO $staff$
DECLARE u uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id) VALUES(u);
 INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'staff');
 INSERT INTO public.staff_permissions(user_id,section_key,subcard_key) VALUES(u,'tables_orders','table_ordering');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
END;$staff$;
SET LOCAL ROLE authenticated;
DO $scope$
DECLARE src text; target uuid;
BEGIN
 PERFORM public.list_cafe_staff_orders('table',true);
 FOREACH src IN ARRAY ARRAY['motel','online','walk_in','all'] LOOP
  BEGIN
   PERFORM public.list_cafe_staff_orders(src,true);
   RAISE EXCEPTION 'Cross-source access allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 BEGIN
  PERFORM public.list_cafe_payment_balances();
  RAISE EXCEPTION 'Table staff payment access allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims',(current_setting('request.jwt.claims')::jsonb||'{"aal":"aal1"}'::jsonb)::text,true);
 BEGIN
  PERFORM public.list_cafe_staff_orders('table',true);
  RAISE EXCEPTION 'Unverified session allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$scope$;
ROLLBACK;
SELECT 'All four order sources, server totals, retries, payment limits, refund limits, status transitions and access checks passed; no test records retained' AS verification;
