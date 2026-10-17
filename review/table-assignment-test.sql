BEGIN;
DO $test$
DECLARE u uuid:=gen_random_uuid();w uuid:=gen_random_uuid();a uuid;b uuid;v uuid;req uuid;m uuid;o jsonb;r uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(w);
 INSERT INTO public.staff_profiles(user_id,role,email) VALUES(u,'admin','manager@test.invalid'),(w,'staff','waiter@test.invalid');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 INSERT INTO public.cafe_dining_tables(name,seats,created_by,updated_by) VALUES('Transfer A',4,u,u) RETURNING id INTO a;
 INSERT INTO public.cafe_dining_tables(name,seats,pricing_mode,created_by,updated_by) VALUES('Transfer B',4,'tourism',u,u) RETURNING id INTO b;
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),a,'take','{"guests":2}');
 PERFORM public.perform_cafe_table_action(gen_random_uuid(),a,'assign_waiter',jsonb_build_object('waiter_id',w));
 SELECT id INTO v FROM public.cafe_table_visits WHERE table_id=a AND closed_at IS NULL;
 IF (SELECT waiter_id FROM public.cafe_table_visits WHERE id=v)<>w THEN RAISE EXCEPTION 'Assignment failed'; END IF;
 SELECT id INTO m FROM public.save_cafe_menu_prices(NULL,'Transfer Tea','Drinks','',1000,true,2000,500);
 o:=public.submit_cafe_priced_order(gen_random_uuid(),'table',a,'',jsonb_build_array(jsonb_build_object('item_id',m,'quantity',1)),'','normal');
 req:=gen_random_uuid();
 PERFORM public.perform_cafe_table_action(req,a,'transfer',jsonb_build_object('target_id',b));
 PERFORM public.perform_cafe_table_action(req,a,'transfer',jsonb_build_object('target_id',b));
 IF NOT EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE id=(o->>'id')::uuid AND original_table_id=a AND table_id=b AND total_iqd=1000 AND pricing_mode='normal') THEN RAISE EXCEPTION 'Transfer lost order snapshot/origin'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.cafe_table_visits WHERE id=v AND table_id=b AND waiter_id=w) THEN RAISE EXCEPTION 'Transfer lost active visit'; END IF;
 IF (SELECT status FROM public.cafe_dining_tables WHERE id=a)<>'cleaning' THEN RAISE EXCEPTION 'Origin not cleaning'; END IF;
 IF (public.get_cafe_visit_bill(b)->>'balance_iqd')::bigint<>1000 THEN RAISE EXCEPTION 'Transferred bill changed'; END IF;
 IF (SELECT count(*) FROM public.get_cafe_table_history(a))<>3 THEN RAISE EXCEPTION 'Missing audit or duplicate transfer'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',w,'aal','aal2','role','authenticated')::text,true);
 BEGIN
  PERFORM public.perform_cafe_table_action(gen_random_uuid(),b,'assign_waiter',jsonb_build_object('waiter_id',u));
  RAISE EXCEPTION 'Unpermitted staff reassigned waiter';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$test$;
ROLLBACK;
