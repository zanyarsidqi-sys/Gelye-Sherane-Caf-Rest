# Upgrade 1174 — Kitchen item names and preparation locations

The Kitchen order item list now requests item names and assigned preparation
station labels through an authorized read-only Supabase RPC, rather than
showing only product IDs. Existing product/station mapping is reused.
Unassigned products are explicitly identified. The database migration must
be deployed before using the new Kitchen screen.

**Still to implement:** customer-per-item identity, notes/modifiers, item-level
assignment and timestamps, service tasks, station-specific queues and device
notifications. No fake customer names or fabricated timestamps are shown.

Flutter compilation and live Supabase verification remain deferred.
