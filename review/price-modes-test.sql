BEGIN;
DO $setup$
DECLARE u uuid:=gen_random_uuid();t uuid;m uuid;q uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(u);
 INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'admin');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 INSERT INTO public.cafe_dining_tables(name,created_by,updated_by) VALUES('Pricing verification',u,u) RETURNING id INTO t;
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'take','{"guests":1}');
 SELECT token INTO q FROM public.cafe_dining_table_qr_tokens WHERE table_id=t;
 IF q IS NULL THEN INSERT INTO public.cafe_dining_table_qr_tokens(table_id) VALUES(t) RETURNING token INTO q; END IF;
 SELECT id INTO m FROM public.save_cafe_menu_prices(NULL,'Priced tea','Drinks','',2500,true,3500,1500);
 PERFORM set_config('test.table',t::text,true); PERFORM set_config('test.product',m::text,true); PERFORM set_config('test.qr',q::text,true);
END;$setup$;
DO $test$
DECLARE mode text; expected bigint; got bigint; result jsonb; req uuid; saved uuid; items jsonb:=jsonb_build_array(jsonb_build_object('item_id',current_setting('test.product'),'quantity',2));
BEGIN
 FOREACH mode IN ARRAY ARRAY['normal','tourism','owner'] LOOP
  expected:=CASE mode WHEN 'tourism' THEN 3500 WHEN 'owner' THEN 1500 ELSE 2500 END;
  UPDATE public.cafe_dining_tables SET pricing_mode=mode WHERE id=current_setting('test.table')::uuid;
  SELECT price_iqd INTO got FROM public.get_cafe_guest_menu(current_setting('test.qr')::uuid) WHERE id=current_setting('test.product')::uuid;
  IF got<>expected THEN RAISE EXCEPTION 'Wrong QR menu price for %',mode; END IF;
  req:=gen_random_uuid();
  result:=public.submit_cafe_guest_table_order(current_setting('test.qr')::uuid,req,items,'');
  IF (result->>'total_iqd')::bigint<>expected*2 OR result->>'pricing_mode'<>mode THEN RAISE EXCEPTION 'Wrong guest price'; END IF;
  IF public.submit_cafe_guest_table_order(current_setting('test.qr')::uuid,req,items,'')->>'id'<>result->>'id' THEN RAISE EXCEPTION 'Guest duplicate'; END IF;
  result:=public.submit_cafe_priced_order(gen_random_uuid(),'table',current_setting('test.table')::uuid,'',items,'',mode);
  IF (result->>'total_iqd')::bigint<>expected*2 THEN RAISE EXCEPTION 'Wrong staff price'; END IF;
  saved:=(result->>'id')::uuid;
 END LOOP;
 BEGIN
  PERFORM public.submit_cafe_priced_order(gen_random_uuid(),'table',current_setting('test.table')::uuid,'',items,'','normal');
  RAISE EXCEPTION 'Client overrode active table mode';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.save_cafe_menu_prices(current_setting('test.product')::uuid,'Priced tea','Drinks','',9000,true,10000,8000);
 IF (public.cafe_table_order_payload(saved)->>'total_iqd')::bigint<>3000 THEN RAISE EXCEPTION 'Old order repriced'; END IF;
 BEGIN
  PERFORM public.save_cafe_menu_prices(NULL,'Bad price','Drinks','',2500,true,-1,1500);
  RAISE EXCEPTION 'Negative price accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END;$test$;
SET LOCAL ROLE anon;
DO $anon$
BEGIN
 IF (SELECT price_iqd FROM public.get_cafe_guest_menu(current_setting('test.qr')::uuid) WHERE id=current_setting('test.product')::uuid)<>8000 THEN RAISE EXCEPTION 'Anonymous QR menu failed'; END IF;
 BEGIN
  PERFORM public.list_cafe_menu_prices();
  RAISE EXCEPTION 'Anonymous staff catalog access';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$anon$;
RESET ROLE;
ROLLBACK;
