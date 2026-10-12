# Section 02 — Tables — Upgrade 150

Replaces legacy occupancy toggles with a visit-aware seating screen.

- Responsive table cards and filters for iPhone/desktop.
- Loads tables plus server-authorized active visits.
- Seat dialog enforces guest count and defaults to Normal pricing.
- Calls `gs_open_cafe_table_visit` to create a visit under a server-side table lock.
- Removes unsafe legacy direct `gs_update_cafe_table` release and
  `gs_transfer_cafe_table` action from this screen.
- Occupied, cleaning and active-visit tables cannot be seated again from UI.

**Deployment warning:** Existing `gs_open_cafe_table_visit` migration is explicitly
marked DRAFT and still has a reservation-hold TODO. Do not deploy it without
reservation and order-visit integration review. The screen will fail closed
if the RPC is not deployed. Live Flutter/Supabase tests not performed.

Next: design and implement a reservation-aware, audited table-visit opening RPC,
then authorized transfer and cancellation workflows. Dashboard remains paused
at Upgrade 149. Phase 3 overall ~54% estimated (not verified).
