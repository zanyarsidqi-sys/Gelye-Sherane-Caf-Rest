# Dashboard Upgrade 43 — Staff service-request creation
- Added New Request dialog: table, service type, quantity, priority, notes.
- Added draft staff-only `gs_create_table_service_task` RPC with permission checks,
  table validation, rate limiting, and active-request duplicate detection.
- No direct table writes from Flutter. Chargeable items remain in order flow.
- Guest QR submissions are NOT implemented; they require a distinct secured flow.
- Migration is a draft; backend schema, compilation and live tests deferred.
- Remaining: automatic checkout cleaning, shisha pickup, release safeguards,
  audit/notification integration and final design previews.
