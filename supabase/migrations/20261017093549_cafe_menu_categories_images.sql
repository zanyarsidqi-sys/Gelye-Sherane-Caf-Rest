BEGIN;
CREATE TABLE public.cafe_menu_categories(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX cafe_menu_categories_name_idx ON public.cafe_menu_categories(lower(trim(name)));
INSERT INTO public.cafe_menu_categories(name) SELECT min(trim(category)) FROM public.cafe_menu_items GROUP BY lower(trim(category));
ALTER TABLE public.cafe_menu_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cafe_menu_categories FROM PUBLIC,anon,authenticated;
ALTER TABLE public.cafe_menu_items ADD COLUMN image_path text;
CREATE FUNCTION cafe_private.category_sync() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN INSERT INTO public.cafe_menu_categories(name) VALUES(trim(NEW.category)) ON CONFLICT DO NOTHING; RETURN NEW; END $$;
REVOKE ALL ON FUNCTION cafe_private.category_sync() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER cafe_menu_category_sync BEFORE INSERT OR UPDATE OF category ON public.cafe_menu_items FOR EACH ROW EXECUTE FUNCTION cafe_private.category_sync();
CREATE FUNCTION cafe_private.menu_assets(p_action text,p_id uuid,p_text text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb; previous text; card text;
BEGIN
 card:=CASE WHEN p_action IN ('categories','save_category') THEN 'product_categories' ELSE 'product_images_descriptions' END;
 IF auth.uid() IS NULL OR NOT (public.has_workspace_access('kitchen_management',card) OR public.has_workspace_access('kitchen_management','edit_manage_products') OR (p_action='categories' AND public.has_workspace_access('kitchen_management','add_new_product'))) THEN RAISE EXCEPTION 'Menu permission and MFA required' USING ERRCODE='42501'; END IF;
 IF p_action='categories' THEN
  SELECT coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('product_count',(SELECT count(*) FROM public.cafe_menu_items m WHERE lower(trim(m.category))=lower(trim(c.name)))) ORDER BY c.name),'[]') INTO result FROM public.cafe_menu_categories c;
 ELSIF p_action='save_category' THEN
  IF p_text IS NULL OR length(trim(p_text)) NOT BETWEEN 1 AND 60 THEN RAISE EXCEPTION 'Enter a category name of 1–60 characters' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(17093549);
  IF p_id IS NULL THEN
   INSERT INTO public.cafe_menu_categories(name) VALUES(trim(p_text)) ON CONFLICT DO NOTHING;
  ELSE
   SELECT name INTO previous FROM public.cafe_menu_categories WHERE id=p_id FOR UPDATE;
   IF previous IS NULL THEN RAISE EXCEPTION 'Category missing; refresh' USING ERRCODE='22023'; END IF;
   UPDATE public.cafe_menu_categories SET name=trim(p_text) WHERE id=p_id;
   UPDATE public.cafe_menu_items SET category=trim(p_text) WHERE lower(trim(category))=lower(trim(previous));
  END IF;
  result:=jsonb_build_object('ok',true);
 ELSIF p_action='images' THEN
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'category',category,'image_path',image_path) ORDER BY name),'[]') INTO result FROM public.cafe_menu_items;
 ELSIF p_action='set_image' THEN
  IF p_text IS NOT NULL AND (split_part(p_text,'/',1)<>auth.uid()::text OR split_part(p_text,'/',2)<>p_id::text OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='cafe-product-images' AND name=p_text)) THEN RAISE EXCEPTION 'Upload a product image first' USING ERRCODE='22023'; END IF;
  UPDATE public.cafe_menu_items SET image_path=p_text WHERE id=p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Product missing' USING ERRCODE='22023'; END IF;
  result:=jsonb_build_object('ok',true);
 ELSE RAISE EXCEPTION 'Invalid action' USING ERRCODE='22023'; END IF;
 RETURN result;
END $$;
CREATE FUNCTION public.manage_cafe_menu_assets(p_action text,p_id uuid DEFAULT NULL,p_text text DEFAULT NULL) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT cafe_private.menu_assets(p_action,p_id,p_text) $$;
REVOKE ALL ON FUNCTION cafe_private.menu_assets(text,uuid,text),public.manage_cafe_menu_assets(text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.menu_assets(text,uuid,text),public.manage_cafe_menu_assets(text,uuid,text) TO authenticated;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('cafe-product-images','cafe-product-images',true,5242880,ARRAY['image/jpeg','image/png']);
CREATE POLICY cafe_product_image_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='cafe-product-images' AND (storage.foldername(name))[1]=auth.uid()::text
 AND (public.has_workspace_access('kitchen_management','product_images_descriptions') OR public.has_workspace_access('kitchen_management','edit_manage_products'))
 AND EXISTS(SELECT 1 FROM public.cafe_menu_items WHERE id::text=(storage.foldername(name))[2])
);
-- Menu history trigger records image association changes on the product.
DO $patch$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('cafe_private.list_menu_priced()'::regprocedure) INTO f;
 f:=replace(f,'''available'',m.available','''available'',m.available,''image_path'',m.image_path');
 EXECUTE f;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
