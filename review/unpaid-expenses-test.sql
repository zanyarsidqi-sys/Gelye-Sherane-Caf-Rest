BEGIN;
DO $test$
DECLARE u uuid:=gen_random_uuid();w uuid:=gen_random_uuid();req uuid;e uuid;p uuid;a jsonb;baseline bigint; data jsonb;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(w); INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'admin'),(w,'staff');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 baseline:=(public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint;
 req:=gen_random_uuid();
 e:=public.create_cafe_expense(req,'Supplier','Purchased tea','Invoice ABC',10000,current_date,current_date+7);
 IF public.create_cafe_expense(req,'Supplier','Purchased tea','Invoice ABC',10000,current_date,current_date+7)<>e THEN RAISE EXCEPTION 'Duplicate purchase'; END IF;
 IF EXISTS(SELECT 1 FROM public.cafe_expense_payments WHERE expense_id=e) THEN RAISE EXCEPTION 'Purchase automatically paid'; END IF;
 a:=public.prepare_cafe_expense_evidence(gen_random_uuid(),e,'invoice.pdf','application/pdf',120);
 IF NOT cafe_private.expense_object_allowed(a->>'path',true) THEN RAISE EXCEPTION 'Uploader cannot upload registered evidence'; END IF;
 IF cafe_private.expense_object_allowed('arbitrary/path.pdf',true) THEN RAISE EXCEPTION 'Unregistered upload permitted'; END IF;
 BEGIN PERFORM public.finish_cafe_expense_evidence((a->>'id')::uuid); RAISE EXCEPTION 'Missing file accepted as uploaded'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>baseline THEN RAISE EXCEPTION 'Unpaid expense reduced cash'; END IF;
 PERFORM public.submit_cafe_cash_entry(gen_random_uuid(),'cash_in',10000,'cash','Expense payment funding');
 req:=gen_random_uuid();
 p:=public.pay_cafe_expense(req,e,4000,'cash','First part');
 IF public.pay_cafe_expense(req,e,4000,'cash','First part')<>p THEN RAISE EXCEPTION 'Duplicate expense payment'; END IF;
 IF (SELECT sum(amount_iqd) FROM public.cafe_expense_payments WHERE expense_id=e)<>4000 THEN RAISE EXCEPTION 'Incorrect partial payment'; END IF;
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>baseline+6000 THEN RAISE EXCEPTION 'Cash not reduced exactly once'; END IF;
 BEGIN PERFORM public.pay_cafe_expense(gen_random_uuid(),e,7000,'cash','Too much'); RAISE EXCEPTION 'Overpayment accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM public.pay_cafe_expense(gen_random_uuid(),e,6000,'manual_card','Terminal receipt');
 IF (SELECT sum(amount_iqd) FROM public.cafe_expense_payments WHERE expense_id=e)<>10000 THEN RAISE EXCEPTION 'Final balance not settled'; END IF;
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>baseline+6000 THEN RAISE EXCEPTION 'Card payment reduced drawer'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',w,'aal','aal2','role','authenticated')::text,true);
 IF cafe_private.expense_object_allowed(a->>'path',false) THEN RAISE EXCEPTION 'Unassigned staff can read evidence'; END IF;
 BEGIN PERFORM public.get_cafe_expenses(); RAISE EXCEPTION 'Unassigned staff can read purchases'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$test$;
SET LOCAL ROLE anon;
DO $anon$ BEGIN
 BEGIN PERFORM public.get_cafe_expenses(); RAISE EXCEPTION 'Guest can read expenses'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='cafe-expense-evidence') THEN RAISE EXCEPTION 'Guest can read evidence'; END IF;
END;$anon$;
ROLLBACK;
