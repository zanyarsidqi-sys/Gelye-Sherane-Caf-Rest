# Upgrade 1209 — Table Orders replacement handoff

Read-only, permission-scoped RPC `gs_table_orders_replacement_delivery_progress` shows replacement preparation, assignment, acceptance, pickup and delivery, including assigned employee names. Table Orders gets a new `Replacement Delivery` tab with 15-second refresh and optional order ID filter. No direct table grants; the SECURITY DEFINER RPC checks `table_orders.can_view`. All changes to delivery state remain under existing Kitchen RPC authorization. Correction history, billing and waste remain unchanged.

## Deferred verification
Flutter compile, SQL migration execution and live Supabase integration are deferred until laptop access.
