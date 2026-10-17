BEGIN;
CREATE FUNCTION cafe_private.product_image_upload_allowed(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT auth.uid() IS NOT NULL AND split_part(p_path,'/',1)=auth.uid()::text
 AND (public.has_workspace_access('kitchen_management','product_images_descriptions') OR public.has_workspace_access('kitchen_management','edit_manage_products'))
 AND EXISTS(SELECT 1 FROM public.cafe_menu_items WHERE id::text=split_part(p_path,'/',2))
$$;
REVOKE ALL ON FUNCTION cafe_private.product_image_upload_allowed(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION cafe_private.product_image_upload_allowed(text) TO authenticated;
ALTER POLICY cafe_product_image_upload ON storage.objects WITH CHECK(bucket_id='cafe-product-images' AND cafe_private.product_image_upload_allowed(name));
DO $patch$ DECLARE f text; BEGIN
 SELECT pg_get_functiondef('cafe_private.guest_portal(uuid)'::regprocedure) INTO f;
 IF position('jsonb_agg(to_jsonb(m)) FROM cafe_private.get_cafe_guest_menu' in f)=0 THEN RAISE EXCEPTION 'Unexpected guest menu projection'; END IF;
 f:=replace(f,'jsonb_agg(to_jsonb(m)) FROM cafe_private.get_cafe_guest_menu','jsonb_agg(to_jsonb(m)||jsonb_build_object(''image_path'',(SELECT i.image_path FROM public.cafe_menu_items i WHERE i.id=m.id))) FROM cafe_private.get_cafe_guest_menu');
 EXECUTE f;
END $patch$;
NOTIFY pgrst,'reload schema';
COMMIT;
