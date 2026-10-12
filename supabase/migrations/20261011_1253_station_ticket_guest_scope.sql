-- Upgrade 1253: station-scoped guest ticket projection.
-- Do not expose guest labels for another station simply because an employee
-- has broad Kitchen view permission. Preserve the legacy RPC signature.
CREATE OR REPLACE FUNCTION public.gs_kitchen_station_ticket_details(p_ticket_id bigint)
RETURNS TABLE(order_item_id bigint, product_name text, quantity integer,
 guest_label text, preparation_notes text, station_name text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_station text;
BEGIN
 IF auth.uid() IS NULL OR coalesce(auth.jwt()->>'aal','') <> 'aal2'
    OR NOT public.gs_can_access('kitchen','can_view') THEN
  RAISE EXCEPTION 'Authenticated Kitchen MFA access required';
 END IF;
 IF p_ticket_id IS NULL OR p_ticket_id <= 0 THEN
  RAISE EXCEPTION 'Valid station ticket required';
 END IF;
 SELECT t.station_key INTO v_station
 FROM public.gs_cafe_order_station_tickets t WHERE t.id=p_ticket_id;
 IF v_station IS NULL THEN RAISE EXCEPTION 'Station ticket not found'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM public.gs_cafe_station_employee_assignments a
  WHERE a.station_key=v_station AND a.employee_id=auth.uid() AND a.active
 ) AND NOT public.gs_1246_can_manage_station(v_station) THEN
  RAISE EXCEPTION 'Not assigned to ticket station';
 END IF;
 RETURN QUERY
 SELECT ti.order_item_id, ti.product_name_snapshot, ti.quantity,
        nullif(btrim(oi.guest_label),'')::text, oi.preparation_notes,
        s.display_name
 FROM public.gs_cafe_order_station_ticket_items ti
 JOIN public.gs_cafe_order_station_tickets t ON t.id=ti.ticket_id
 JOIN public.gs_cafe_preparation_stations s ON s.station_key=t.station_key
 JOIN public.gs_order_items oi ON oi.id=ti.order_item_id
 WHERE ti.ticket_id=p_ticket_id AND t.station_key=v_station
 ORDER BY ti.order_item_id;
END $$;
REVOKE ALL ON FUNCTION public.gs_kitchen_station_ticket_details(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.gs_kitchen_station_ticket_details(bigint) TO authenticated;
