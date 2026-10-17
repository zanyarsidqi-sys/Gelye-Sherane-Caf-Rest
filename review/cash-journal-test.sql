BEGIN;
DO $test$
DECLARE u uuid:=gen_random_uuid(); w uuid:=gen_random_uuid(); req uuid; entry uuid; balance bigint; result jsonb; c uuid;
BEGIN
 INSERT INTO auth.users(id) VALUES(u),(w);
 INSERT INTO public.staff_profiles(user_id,role) VALUES(u,'admin'),(w,'staff');
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'aal','aal2','role','authenticated')::text,true);
 balance:=(public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint;
 req:=gen_random_uuid();
 entry:=public.submit_cafe_cash_entry(req,'cash_in',10000,'cash','Opening cash verification');
 IF public.submit_cafe_cash_entry(req,'cash_in',10000,'cash','Opening cash verification')<>entry THEN RAISE EXCEPTION 'Duplicate cash in'; END IF;
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>balance+10000 THEN RAISE EXCEPTION 'Cash-in balance incorrect'; END IF;
 entry:=public.submit_cafe_cash_entry(gen_random_uuid(),'expense',3000,'cash','Tea supplies');
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>balance+10000 THEN RAISE EXCEPTION 'Pending expense reduced cash'; END IF;
 PERFORM public.review_cafe_cash_entry(entry,true,'Receipt checked');
 PERFORM public.review_cafe_cash_entry(entry,true,'Receipt checked');
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>balance+7000 THEN RAISE EXCEPTION 'Approved expense balance incorrect'; END IF;
 c:=public.submit_cafe_cash_entry(gen_random_uuid(),'count',6500,'cash','Closing count');
 IF NOT EXISTS(SELECT 1 FROM public.cafe_cash_counts WHERE id=c AND expected_iqd=balance+7000 AND counted_iqd=6500) THEN RAISE EXCEPTION 'Count snapshot incorrect'; END IF;
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>balance+7000 THEN RAISE EXCEPTION 'Count changed ledger'; END IF;
 entry:=public.submit_cafe_cash_entry(gen_random_uuid(),'expense',1000,'manual_card','Manual card expense');
 PERFORM public.review_cafe_cash_entry(entry,true,'Card receipt checked');
 IF (public.get_cafe_cash_workspace('payment_management','standing_cash')->>'balance_iqd')::bigint<>balance+7000 THEN RAISE EXCEPTION 'Card expense reduced drawer'; END IF;
 entry:=public.submit_cafe_cash_entry(gen_random_uuid(),'cash_out',greatest(balance+8000,1),'cash','Excess withdrawal');
 BEGIN PERFORM public.review_cafe_cash_entry(entry,true,'Reviewed'); RAISE EXCEPTION 'Cash overdraft accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',w,'aal','aal2','role','authenticated')::text,true);
 BEGIN PERFORM public.get_cafe_cash_workspace('payment_management','standing_cash'); RAISE EXCEPTION 'Unassigned cash read'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$test$;
SET LOCAL ROLE anon;
DO $anon$ BEGIN
 BEGIN PERFORM public.get_cafe_cash_workspace('payment_management','standing_cash'); RAISE EXCEPTION 'Guest cash read'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM 1 FROM public.cafe_cash_journal; RAISE EXCEPTION 'Direct ledger access'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;$anon$;
ROLLBACK;
