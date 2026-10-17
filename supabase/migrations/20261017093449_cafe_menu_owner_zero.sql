BEGIN;
ALTER TABLE public.cafe_menu_items DROP CONSTRAINT cafe_menu_items_owner_price_iqd_check;
ALTER TABLE public.cafe_menu_items ADD CONSTRAINT cafe_menu_items_owner_price_iqd_check CHECK(owner_price_iqd BETWEEN 0 AND 999999999);
ALTER TABLE public.cafe_table_orders DROP CONSTRAINT cafe_table_orders_total_iqd_check;
ALTER TABLE public.cafe_table_orders ADD CONSTRAINT cafe_table_orders_total_iqd_check CHECK(total_iqd BETWEEN 0 AND 19999999980 AND (total_iqd>0 OR pricing_mode='owner'));
ALTER TABLE public.cafe_table_order_items DROP CONSTRAINT cafe_table_order_items_unit_price_iqd_check;
ALTER TABLE public.cafe_table_order_items ADD CONSTRAINT cafe_table_order_items_unit_price_iqd_check CHECK(unit_price_iqd BETWEEN 0 AND 999999999);
DO $patch$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('cafe_private.save_menu_priced(uuid,text,text,text,bigint,boolean,bigint,bigint)'::regprocedure) INTO f;
 IF position('p_owner_price_iqd NOT BETWEEN 1 AND 999999999' in f)=0 THEN RAISE EXCEPTION 'Unexpected price validator; review before changing'; END IF;
 f:=replace(f,'p_owner_price_iqd NOT BETWEEN 1 AND 999999999','p_owner_price_iqd NOT BETWEEN 0 AND 999999999');
 f:=replace(f,'Enter all three whole IQD prices from 1 to 999999999','Normal and Tourism prices must be positive; Owner price may be zero');
 EXECUTE f;
END $patch$;
CREATE FUNCTION cafe_private.validate_zero_owner_line() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.unit_price_iqd=0 AND NOT EXISTS(SELECT 1 FROM public.cafe_table_orders WHERE id=NEW.order_id AND pricing_mode='owner') THEN
 RAISE EXCEPTION 'Zero-priced items require Owner mode' USING ERRCODE='22023';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION cafe_private.validate_zero_owner_line() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER cafe_validate_zero_owner_line BEFORE INSERT OR UPDATE OF unit_price_iqd,order_id ON public.cafe_table_order_items FOR EACH ROW EXECUTE FUNCTION cafe_private.validate_zero_owner_line();
NOTIFY pgrst,'reload schema';
COMMIT;
