# Section 02 - Tables - Upgrade 153

Added a reservation check-in action to the actual Flutter Tables screen. The
button fetches eligible approved reservations through a permission-scoped
SECURITY DEFINER RPC, lets staff select a reservation, calls the existing
atomic `gs_check_in_cafe_reservation` RPC, and reloads the table grid.

New migration `20261010_153_reservation_checkin_list.sql` provides the queue,
without granting clients direct SELECT access to private reservation records.
Only approved, not-yet-checked-in reservations in their check-in window are
listed. Customer phone numbers are not exposed in the list.

**Not yet tested against Supabase or compiled in Flutter.** Staging deployment
and runtime verification are required. No payment or checkout gates changed.
Tables section completion is an **estimated 20%**; no production verification.
