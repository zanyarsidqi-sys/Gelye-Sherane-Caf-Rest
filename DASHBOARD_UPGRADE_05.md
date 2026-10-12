# Dashboard coding upgrade 05

Added `lib/screens/dashboard/live_table_map.dart` and integrated it into the Dashboard.

- Authorized employees with `tables` access can see the Live Table Map.
- It consumes an optional `table_map` array in the existing dashboard RPC response; it does not fake tables or numbers.
- Table selection opens full-screen details on narrow devices and a right-side panel on desktop.
- Detail rows display only fields supplied by the server (status, guest count, optional name, bill, paid and remaining).
- If the RPC has no table_map field, the widget shows an honest empty state.

**Remaining:** implement permission-filtered `table_map` RPC data, persisted floor positions and editor, table order/guest linkage, split-payment endpoints, and PC compilation/integration verification. No migrations applied. Progress estimate remains unchanged.
