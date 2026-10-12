# Upgrade 233 — Preparation Station Dispatch Center

- Added a Flutter dialog in Section 02 Tables with recent station tickets, destination, status, attempts, and failures.
- Manager retry confirmation requires a reason and warns of potential duplicate physical paper output.
- Added permission-gated `gs_list_station_dispatch_tickets()` RPC, capped at 200 rows.
- Existing `gs_list_station_dispatch_alerts()` and `gs_retry_station_ticket()` are reused.
- Dispatch status is metadata only; no device SDK, print rendering, driver, gateway, or offline delivery is included.
- Requires migration 233 after all prior migrations. Flutter and live Supabase integration have not been executed.
