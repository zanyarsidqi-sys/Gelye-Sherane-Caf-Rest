-- Upgrade 1254: enforce station boundaries on Kitchen ticket and correction queues.
-- This migration preserves legacy RPC signatures and output columns.
-- No guest name or note is returned from the queue functions.
CREATE OR REPLACE FUNCTION public.gs_kitchen_station_ticket_queue()
RETURNS TABLE(ticket_id bigint, order_id bigint, station_key text,
 station_name text, ticket_status text, delivery_method text,
 created_at timestamptz, item_count bigint, item_quantity bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF auth.uid() IS NULL OR coalesce(auth.jwt()->>'aal','') <> 'aal2'
    OR NOT public.gs_can_access('kitchen','can_view') THEN
  RAISE EXCEPTION 'Kitchen MFA view permission required';
 END IF;
 RETURN QUERY
 SELECT t.id,t.order_id,t.station_key,s.display_name,t.status,
        t.delivery_method,t.created_at,count(ti.order_item_id)::bigint,
        coalesce(sum(ti.quantity),0)::bigint
 FROM public.gs_cafe_order_station_tickets t
 JOIN public.gs_cafe_preparation_stations s ON s.station_key=t.station_key
 LEFT JOIN public.gs_cafe_order_station_ticket_items ti ON ti.ticket_id=t.id
 WHERE t.status IN ('queued','received','failed','unknown')
 AND (
   EXISTS (SELECT 1 FROM public.gs_cafe_station_employee_assignments a
           WHERE a.station_key=t.station_key AND a.employee_id=auth.uid() AND a.active)
   OR public.gs_1246_can_manage_station(t.station_key)
 )
 GROUP BY t.id,t.order_id,t.station_key,s.display_name,t.status,t.delivery_method,t.created_at
 ORDER BY t.created_at ASC,t.id ASC LIMIT 250;
END $$;
REVOKE ALL ON FUNCTION public.gs_kitchen_station_ticket_queue() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gs_kitchen_station_ticket_queue() TO authenticated;

CREATE OR REPLACE FUNCTION public.gs_kitchen_correction_revision_queue()
RETURNS TABLE(revision_id bigint,correction_id bigint,order_id bigint,station_key text,
 revision_kind text,order_item_id bigint,product_name text,quantity integer,
 state text,created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR coalesce(auth.jwt()->>'aal','') <> 'aal2'
    OR NOT public.gs_can_access('kitchen','can_view') THEN
  RAISE EXCEPTION 'Kitchen MFA view permission required';
 END IF;
 RETURN QUERY
 SELECT r.id,r.correction_id,r.order_id,r.station_key,r.revision_kind,
        r.order_item_id,p.name,r.quantity,r.state,r.created_at
 FROM public.gs_cafe_correction_station_revisions r
 JOIN public.gs_order_items i ON i.id=r.order_item_id
 JOIN public.gs_menu_products p ON p.id=i.product_id
 WHERE EXISTS (
   SELECT 1 FROM public.gs_cafe_station_employee_assignments a
   WHERE a.station_key=r.station_key AND a.employee_id=auth.uid() AND a.active
 ) OR public.gs_1246_can_manage_station(r.station_key)
 ORDER BY (r.state='pending') DESC,r.created_at DESC LIMIT 250;
END $$;
REVOKE ALL ON FUNCTION public.gs_kitchen_correction_revision_queue() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gs_kitchen_correction_revision_queue() TO authenticated;

CREATE OR REPLACE FUNCTION public.gs_ack_correction_station_revision(
 p_revision_id bigint,p_unable_to_stop boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.gs_cafe_correction_station_revisions%rowtype;
BEGIN
 IF auth.uid() IS NULL OR coalesce(auth.jwt()->>'aal','') <> 'aal2'
    OR NOT public.gs_can_access('kitchen','can_edit') THEN
  RAISE EXCEPTION 'Kitchen MFA edit permission required';
 END IF;
 IF p_revision_id IS NULL OR p_revision_id<=0 THEN
  RAISE EXCEPTION 'Valid revision required';
 END IF;
 SELECT * INTO r FROM public.gs_cafe_correction_station_revisions
 WHERE id=p_revision_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Revision unavailable'; END IF;
 IF NOT (
   EXISTS (SELECT 1 FROM public.gs_cafe_station_employee_assignments a
     WHERE a.station_key=r.station_key AND a.employee_id=auth.uid() AND a.active)
   OR public.gs_1246_can_manage_station(r.station_key)
 ) THEN RAISE EXCEPTION 'Not authorized for revision station'; END IF;
 IF p_unable_to_stop AND r.revision_kind<>'stop_wrong_item' THEN
  RAISE EXCEPTION 'Unable-to-stop applies only to incorrect preparation';
 END IF;
 IF r.state<>'pending' THEN RETURN; END IF;
 UPDATE public.gs_cafe_correction_station_revisions SET
 state=CASE WHEN p_unable_to_stop THEN 'unable_to_stop' ELSE 'acknowledged' END,
 acknowledged_at=transaction_timestamp(),acknowledged_by=auth.uid()
 WHERE id=p_revision_id AND state='pending';
 INSERT INTO public.gs_system_audit_events(actor_id,section,action,record_id,after_data)
 VALUES(auth.uid(),'kitchen','correction_revision_ack',p_revision_id::text,
 jsonb_build_object('unable_to_stop',p_unable_to_stop,'station_key',r.station_key));
END $$;
REVOKE ALL ON FUNCTION public.gs_ack_correction_station_revision(bigint,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gs_ack_correction_station_revision(bigint,boolean) TO authenticated;
