BEGIN;
DO $test$
DECLARE u uuid:=gen_random_uuid(); t uuid; q uuid; m uuid; v uuid; req uuid; o jsonb; items jsonb; r uuid; overview jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(u);
 INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'admin');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 INSERT INTO public.cafe_dining_tables(name,created_by,updated_by) VALUES('Visit verification',u,u) RETURNING id INTO t;
 SELECT token INTO q FROM public.cafe_dining_table_qr_tokens WHERE table_id=t;
 IF q IS NULL THEN INSERT INTO public.cafe_dining_table_qr_tokens(table_id) VALUES(t) RETURNING token INTO q; END IF;
 SELECT id INTO m FROM public.save_cafe_menu_prices(NULL,'Visit tea','Drinks','',1000,true,2000,500);
 items:=jsonb_build_array(jsonb_build_object('item_id',m,'quantity',2));
 IF public.get_cafe_guest_portal(q)->>'visit_id' IS NOT NULL THEN RAISE EXCEPTION 'Invented visit'; END IF;
 BEGIN
  PERFORM public.submit_cafe_guest_table_order(q,gen_random_uuid(),items,'');
  RAISE EXCEPTION 'Order accepted before Take';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 req:=gen_random_uuid();
 PERFORM public.perform_cafe_table_action(req,t,'take','{"guests":2}');
 PERFORM public.perform_cafe_table_action(req,t,'take','{"guests":2}');
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=t AND closed_at IS NULL;
 IF (SELECT count(*) FROM public.cafe_table_visits WHERE table_id=t)<>1 THEN RAISE EXCEPTION 'Duplicate visit'; END IF;
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'mode','{"mode":"tourism","reason":"Visitor pricing"}');
 BEGIN
  PERFORM public.submit_cafe_guest_quoted_order(q,gen_random_uuid(),items,'',v,2000,'normal');
  RAISE EXCEPTION 'Stale mode accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.submit_cafe_guest_quoted_order(q,gen_random_uuid(),items,'',v,2000,'tourism');
  RAISE EXCEPTION 'Stale total accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE table_id=t) THEN RAISE EXCEPTION 'Rejected quote left charges'; END IF;
 req:=gen_random_uuid();
 o:=public.submit_cafe_guest_quoted_order(q,req,items,'',v,4000,'tourism');
 IF public.submit_cafe_guest_quoted_order(q,req,items,'',v,4000,'tourism')->>'id'<>o->>'id' THEN RAISE EXCEPTION 'Duplicate QR order'; END IF;
 BEGIN
  PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'close','{}');
  RAISE EXCEPTION 'Unpaid visit closed';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.capture_cafe_payment(gen_random_uuid(),(o->>'id')::uuid,4000,'cash','');
 overview:=public.get_cafe_table_overview();
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(overview->'tables') x WHERE x->>'id'=t::text AND x->>'status'='occupied' AND x->>'payment_status'='Paid — Still Seated') THEN RAISE EXCEPTION 'Payment vacated table or incorrect indicator'; END IF;
 PERFORM public.transition_cafe_order((o->>'id')::uuid,'preparing');
 PERFORM public.transition_cafe_order((o->>'id')::uuid,'ready');
 PERFORM public.transition_cafe_order((o->>'id')::uuid,'served');
 r:=public.submit_cafe_guest_service(q,gen_random_uuid(),'special_request','Extra cups');
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'acknowledge',jsonb_build_object('request_id',r));
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'complete_request',jsonb_build_object('request_id',r));
 IF (SELECT status FROM public.cafe_service_requests WHERE id=r)<>'completed' THEN RAISE EXCEPTION 'Service not completed'; END IF;
 -- A new order reopens the balance and old receipts remain unchanged.
 o:=public.submit_cafe_staff_order(gen_random_uuid(),'table',t,'',items,'');
 IF (o->>'total_iqd')::bigint<>4000 THEN RAISE EXCEPTION 'Legacy staff endpoint ignored table mode'; END IF;
 IF (public.get_cafe_visit_bill(t)->>'balance_iqd')::bigint<>4000 THEN RAISE EXCEPTION 'New order did not reopen balance'; END IF;
 PERFORM public.transition_cafe_order((o->>'id')::uuid,'cancelled');
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'close','{}');
 IF NOT EXISTS(SELECT 1 FROM public.cafe_dining_tables WHERE id=t AND status='cleaning' AND pricing_mode='normal') THEN RAISE EXCEPTION 'Close did not start cleaning/reset mode'; END IF;
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'ready','{}');
 IF (public.get_cafe_guest_portal(q)->'bill'->>'total_iqd')::bigint<>0 THEN RAISE EXCEPTION 'Closed bill exposed to next visitor'; END IF;
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),t,'take','{"guests":1}');
 BEGIN
  PERFORM public.submit_cafe_guest_quoted_order(q,gen_random_uuid(),items,'',v,2000,'normal');
  RAISE EXCEPTION 'Old visit order accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('test.qr',q::text,true);
END;$test$;
SET LOCAL ROLE anon;
DO $anon$
BEGIN
 PERFORM public.get_cafe_guest_portal(current_setting('test.qr')::uuid);
 BEGIN PERFORM public.get_cafe_table_overview(); RAISE EXCEPTION 'Guest accessed staff overview'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM 1 FROM public.cafe_table_visits; RAISE EXCEPTION 'Guest read private visits'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$anon$;
ROLLBACK;
