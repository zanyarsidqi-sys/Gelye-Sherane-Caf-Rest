# Upgrade 1244 — Kitchen customer and station visibility

- Main Kitchen order cards now show customer label(s) and station name(s) from the existing server-authorized `gs_kitchen_order_item_details` RPC. They do not query unrestricted customer profiles or phone numbers.
- Multiple named guests/stations are shown as distinct sorted labels; missing guest labels use the existing Guest N/Table Order fallback, and missing stations say Unassigned station.
- Station preparation ticket headers and item previews explicitly show the station name; per-item guest identity remains sourced from `gs_kitchen_station_ticket_details`.
- All management stays inside Kitchen, with no Workplace dependency added.
- Print adapters and actual hardware receipts are unchanged; no claim of physical POS printing is made.
- Deferred: Flutter compilation, live Supabase/RLS validation, printer hardware tests. Verify the server RPC enforces Kitchen permissions and station scoping before production use.
