# Upgrade 1220 — Station request inbox

- Added a Kitchen Station Requests tab for server-scoped customer service requests and station notifications.
- Employee may select from all authorized station queues; multi-station membership is supported by existing RPCs.
- Added station-alert mark-as-seen RPC with employee identity and active-station validation.
- Price questions currently use the existing cashier request category, with configurable Cashier/Pricing station route; no dedicated customer pricing action has yet been implemented.
- Existing request-to-station routing and notification fanout are preserved from Upgrade 1219.
- Pending: dedicated public pricing request, service printing, printer worker, full station read-permission audit, live integration verification.
- Flutter compilation, Supabase deployment and printer hardware tests intentionally deferred.
