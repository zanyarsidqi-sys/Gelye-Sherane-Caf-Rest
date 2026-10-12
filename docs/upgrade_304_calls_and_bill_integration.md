# Upgrade 304 — Customer calls and private bill preview
- Added staff customer-call queue to Table Orders, refreshed every 8 seconds while screen is mounted; actions Accept / On my way / Complete use existing permission-checked RPCs. In-app notification uses a snackbar when a new waiting call appears; this is **not** background push notification.
- Added visit-token-scoped bill preview RPC and Flutter screen, showing gross ordered items only. It intentionally does not claim payable balance or expose financial ledgers.
- Remaining: wire customer bill screen to QR menu navigation; verify table visit status schema; test migrations against live Supabase; add device push notification and supervisor escalation; reconcile final bill with ledger.
- No Flutter compilation or Supabase deployment performed.
