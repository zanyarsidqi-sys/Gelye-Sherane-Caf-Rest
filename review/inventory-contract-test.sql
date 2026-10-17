
\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database()<>'task_workflow_test' THEN RAISE EXCEPTION 'Isolated database required'; END IF; END $$;
\i supabase/migrations/20261017143246_cafe_inventory_purchasing.sql
SELECT set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.aal','aal2',false);
DO $$ DECLARE i jsonb; p jsonb; r jsonb; again jsonb; req uuid; iid uuid; pid uuid; ver int; q text; BEGIN
 FOREACH q IN ARRAY ARRAY['-1','0','1.0001','NaN','1e3'] LOOP
  BEGIN PERFORM cafe_private.inventory_quantity(q); RAISE EXCEPTION 'Bad quantity accepted: %',q;
  EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 END LOOP;
 i:=public.perform_cafe_inventory_command(gen_random_uuid(),'create_item',null,null,
  '{"name":"Milk","unit":"litre","department":"drinks","reorder_level":"20","on_hand":"999"}');
 iid:=(i->>'id')::uuid;
 IF i->>'on_hand'<>'0.000' THEN RAISE EXCEPTION 'Client supplied opening balance accepted'; END IF;
 req:=gen_random_uuid();
 r:=public.perform_cafe_inventory_command(req,'opening',iid,1,'{"quantity":"10.250","note":"Verified opening count"}');
 again:=public.perform_cafe_inventory_command(req,'opening',iid,1,'{"quantity":"10.250","note":"Verified opening count"}');
 IF r<>again OR (r->>'on_hand')::numeric<>10.25 THEN RAISE EXCEPTION 'Opening retry duplicated'; END IF;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'opening',iid,2,'{"quantity":"1","note":"Second opening"}');
  RAISE EXCEPTION 'Second opening accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'update_item',iid,2,
   '{"name":"Milk","unit":"pack","department":"drinks","reorder_level":"20"}');
  RAISE EXCEPTION 'Unit changed after movement';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 p:=public.perform_cafe_inventory_command(gen_random_uuid(),'request',null,null,
  jsonb_build_object('item_id',iid,'supplier','Dairy supplier','quantity','5','note','Morning delivery'));
 pid:=(p->>'id')::uuid;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,1,'{"quantity":"1","note":"Truck arrived"}');
  RAISE EXCEPTION 'Unapproved receipt accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'approve',pid,1,'{}');
 req:=gen_random_uuid();
 r:=public.perform_cafe_inventory_command(req,'receive',pid,2,'{"quantity":"2","note":"Delivery note D1"}');
 again:=public.perform_cafe_inventory_command(req,'receive',pid,2,'{"quantity":"2","note":"Delivery note D1"}');
 IF r<>again OR r->>'status'<>'part_received' OR (r->>'received')::numeric<>2 THEN RAISE EXCEPTION 'Receipt retry duplicated'; END IF;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,2,'{"quantity":"1","note":"Stale delivery"}');
  RAISE EXCEPTION 'Stale delivery accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,3,'{"quantity":"4","note":"Too much delivery"}');
  RAISE EXCEPTION 'Over receipt accepted';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 r:=public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,3,'{"quantity":"3","note":"Delivery note D2"}');
 IF r->>'status'<>'received' THEN RAISE EXCEPTION 'Full delivery not completed'; END IF;
 SELECT version INTO ver FROM public.cafe_inventory_items WHERE id=iid;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'waste',iid,ver,'{"quantity":"16","note":"Exceeds stock"}');
  RAISE EXCEPTION 'Negative stock allowed';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 req:=gen_random_uuid();
 r:=public.perform_cafe_inventory_command(req,'waste',iid,ver,'{"quantity":"0.250","note":"Damaged package"}');
 again:=public.perform_cafe_inventory_command(req,'waste',iid,ver,'{"quantity":"0.250","note":"Damaged package"}');
 IF r<>again OR (r->>'on_hand')::numeric<>15 THEN RAISE EXCEPTION 'Waste balance or retry incorrect'; END IF;
 IF (SELECT count(*) FROM public.cafe_inventory_movements WHERE item_id=iid)<>4 THEN RAISE EXCEPTION 'Duplicate movements'; END IF;
 IF (SELECT sum(quantity) FROM public.cafe_inventory_movements WHERE item_id=iid)<>15 THEN RAISE EXCEPTION 'Ledger differs from stock'; END IF;
 p:=public.perform_cafe_inventory_command(gen_random_uuid(),'request',null,null,
  jsonb_build_object('item_id',iid,'supplier','Dairy supplier','quantity','4'));
 pid:=(p->>'id')::uuid;
 PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'approve',pid,1,'{}');
 PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,2,'{"quantity":"1","note":"One litre delivered"}');
 PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'cancel',pid,3,'{"note":"Supplier cannot deliver balance"}');
 IF (SELECT on_hand FROM public.cafe_inventory_items WHERE id=iid)<>16 THEN RAISE EXCEPTION 'Cancellation reversed received stock'; END IF;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'receive',pid,4,'{"quantity":"1","note":"After cancellation"}');
  RAISE EXCEPTION 'Cancelled request received';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'create_item',null,null,
  '{"name":"Paper","unit":"pack","department":"general","reorder_level":"5"}');
 IF jsonb_array_length(public.get_cafe_inventory_workspace('low_stock','')->'items')<>1 OR
    jsonb_array_length(public.get_cafe_inventory_workspace('low_stock_alerts','')->'items')<>2 THEN RAISE EXCEPTION 'Low-stock scopes incorrect'; END IF;
 IF jsonb_array_length(public.get_cafe_inventory_workspace('inventory_overview','MILK')->'items')<>1 THEN RAISE EXCEPTION 'Search failed'; END IF;
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000002',false);
 INSERT INTO public.staff_permissions VALUES(auth.uid(),'dashboard','low_stock',null);
 r:=public.get_cafe_inventory_workspace('low_stock','');
 IF r->'can_manage'<>'false'::jsonb OR r->'can_waste'<>'false'::jsonb OR jsonb_array_length(r->'purchases')<>0 THEN RAISE EXCEPTION 'Read scope leaked capabilities/data'; END IF;
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'waste',iid,5,'{"quantity":"1","note":"Not permitted"}');
  RAISE EXCEPTION 'Low-stock viewer changed stock';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 INSERT INTO public.staff_permissions VALUES(auth.uid(),'dashboard','pending_approvals',null);
 BEGIN
  PERFORM public.perform_cafe_inventory_command(gen_random_uuid(),'approve',pid,4,'{}');
  RAISE EXCEPTION 'Non-admin approved purchase';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.aal','aal1',false);
 BEGIN
  PERFORM public.get_cafe_inventory_workspace('low_stock','');
  RAISE EXCEPTION 'MFA bypass';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.aal','aal2',false);
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
 IF has_table_privilege('authenticated','public.cafe_inventory_items','UPDATE') OR
  has_function_privilege('anon','public.perform_cafe_inventory_command(uuid,text,uuid,integer,jsonb)','EXECUTE') THEN
  RAISE EXCEPTION 'Direct or anonymous write access'; END IF;
END $$;
SET ROLE authenticated;
SELECT public.get_cafe_inventory_workspace('inventory_overview','Milk');
RESET ROLE;
SELECT 'Inventory ledger and purchasing contract checks passed' AS result;
