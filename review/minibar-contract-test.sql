\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database()<>'task_workflow_test' THEN RAISE EXCEPTION 'Isolated database required'; END IF; END $$;
-- Existing production station/order interfaces, with only columns used by this migration.
CREATE TABLE public.cafe_print_stations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text,active boolean DEFAULT true);
CREATE TABLE public.cafe_table_orders(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),table_id uuid,source text,destination text,notes text,status text,created_at timestamptz DEFAULT now());
CREATE TABLE public.cafe_table_order_items(id bigint PRIMARY KEY,order_id uuid REFERENCES public.cafe_table_orders,item_name text,quantity integer);
CREATE TABLE public.cafe_station_tickets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),item_id bigint REFERENCES public.cafe_table_order_items,station_id uuid REFERENCES public.cafe_print_stations,event text,confirmed_at timestamptz);
ALTER TABLE public.cafe_print_stations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_print_stations FROM PUBLIC,anon,authenticated;
CREATE FUNCTION cafe_private.print_access(p_manage boolean DEFAULT false) RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT auth.uid() IS NOT NULL AND auth.jwt()->>'aal'='aal2' AND public.has_workspace_access('customer_management','kitchen_stations_management')
$$;
\i supabase/migrations/20261017151125_cafe_minibar_boards.sql
SELECT set_config('test.actor','00000000-0000-0000-0000-000000000001',false);
SELECT set_config('test.aal','aal2',false);
DO $$ DECLARE n uuid; d uuid; k uuid; unknown uuid; orderid uuid; r jsonb; again jsonb; req uuid; BEGIN
 INSERT INTO public.cafe_print_stations(name) VALUES('Station A') RETURNING id INTO n;
 INSERT INTO public.cafe_print_stations(name) VALUES('Station B') RETURNING id INTO d;
 INSERT INTO public.cafe_print_stations(name) VALUES('Station C') RETURNING id INTO k;
 INSERT INTO public.cafe_print_stations(name) VALUES('Nargile misleading name') RETURNING id INTO unknown;
 INSERT INTO public.cafe_table_orders(source,destination,notes,status) VALUES('table','Table 1','No sugar','preparing') RETURNING id INTO orderid;
 INSERT INTO public.cafe_table_order_items VALUES(1,orderid,'Nargile',1),(2,orderid,'Tea',2),(3,orderid,'Food',1),(4,orderid,'Unknown',1);
 INSERT INTO public.cafe_station_tickets(item_id,station_id,event) VALUES(1,n,'new'),(2,d,'new'),(3,k,'new'),(4,unknown,'new');
 IF public.get_cafe_minibar_board('minibar_live_board')->>'total'<>'0' THEN RAISE EXCEPTION 'Station names inferred type'; END IF;
 req:=gen_random_uuid();
 r:=public.classify_cafe_station('minibar_live_board',req,n,1,'nargile');
 again:=public.classify_cafe_station('minibar_live_board',req,n,1,'nargile');
 IF r<>again OR (SELECT count(*) FROM cafe_private.station_classifications)<>1 THEN RAISE EXCEPTION 'Classification retry duplicated'; END IF;
 PERFORM public.classify_cafe_station('minibar_live_board',gen_random_uuid(),d,1,'drinks');
 PERFORM public.classify_cafe_station('minibar_live_board',gen_random_uuid(),k,1,'kitchen');
 BEGIN
  PERFORM public.classify_cafe_station('minibar_live_board',gen_random_uuid(),n,1,'drinks');RAISE EXCEPTION 'Stale version accepted';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
 BEGIN
  PERFORM public.classify_cafe_station('minibar_live_board',gen_random_uuid(),n,2,'drinks');RAISE EXCEPTION 'Used department changed';
 EXCEPTION WHEN sqlstate '22023' THEN NULL; END;
 r:=public.get_cafe_minibar_board('minibar_live_board');
 IF r->>'total'<>'2' OR r->>'unclassified_stations'<>'1' THEN RAISE EXCEPTION 'Minibar scope incorrect'; END IF;
 IF public.get_cafe_minibar_board('nargile_orders')->>'total'<>'1' THEN RAISE EXCEPTION 'Nargile scope incorrect'; END IF;
 IF public.get_cafe_minibar_board('minibar_live_board',false,'TEA')->>'total'<>'1' THEN RAISE EXCEPTION 'Search failed'; END IF;
 UPDATE public.cafe_station_tickets SET confirmed_at=now() WHERE station_id=n;
 IF public.get_cafe_minibar_board('nargile_orders')->>'total'<>'1' THEN RAISE EXCEPTION 'Printed items disappeared'; END IF;
 INSERT INTO public.cafe_station_tickets(item_id,station_id,event) VALUES(1,n,'cancelled');
 IF public.get_cafe_minibar_board('nargile_orders')->>'total'<>'1' THEN RAISE EXCEPTION 'Cancellation ticket duplicated item'; END IF;
 UPDATE public.cafe_table_orders SET status='cancelled' WHERE id=orderid;
 IF public.get_cafe_minibar_board('nargile_orders')->>'total'<>'0' OR public.get_cafe_minibar_board('nargile_orders',true)->>'total'<>'1' THEN RAISE EXCEPTION 'History split failed'; END IF;
 UPDATE public.cafe_table_orders SET created_at=now()-interval '8 days' WHERE id=orderid;
 IF public.get_cafe_minibar_board('nargile_orders',true)->>'total'<>'0' THEN RAISE EXCEPTION 'History limit failed'; END IF;
 UPDATE public.cafe_table_orders SET status='received',created_at=now() WHERE id=orderid;
 PERFORM set_config('test.actor','00000000-0000-0000-0000-000000000002',false);
 INSERT INTO public.staff_permissions VALUES(auth.uid(),'dashboard','nargile_orders',null);
 r:=public.get_cafe_minibar_board('nargile_orders');
 IF r->>'can_classify'<>'false' OR jsonb_array_length(r->'stations')<>1 OR r->>'total'<>'1' THEN RAISE EXCEPTION 'Staff scope leaked'; END IF;
 BEGIN
  PERFORM public.get_cafe_minibar_board('minibar_live_board');RAISE EXCEPTION 'Wrong card accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.classify_cafe_station('nargile_orders',gen_random_uuid(),unknown,1,'nargile');RAISE EXCEPTION 'Staff classified';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.aal','aal1',false);
 BEGIN
  PERFORM public.get_cafe_minibar_board('nargile_orders');RAISE EXCEPTION 'MFA bypass';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('test.aal','aal2',false);
 IF has_function_privilege('anon','public.get_cafe_minibar_board(text,boolean,text)','EXECUTE') OR
 has_table_privilege('authenticated','public.cafe_print_stations','UPDATE') OR
 has_table_privilege('authenticated','cafe_private.station_classifications','SELECT') THEN RAISE EXCEPTION 'Privileges leaked'; END IF;
END $$;
SET ROLE authenticated;
SELECT public.get_cafe_minibar_board('nargile_orders');
RESET ROLE;
SELECT 'Minibar classification and scoped board contracts passed' AS result;
