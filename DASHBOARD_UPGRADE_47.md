# Dashboard Upgrade 47 — Motel meal offers
- Added a Motel Meal Offers shortcut to the Dashboard for employees with motel_orders permission.
- iPhone opens full-screen; Windows opens a right-side detail panel.
- Read-only upcoming/all delivery queue: room, delivery time, meal summary,
  payment arrangement and payment verification status.
- Added a draft Supabase table and permission-checked read RPC.
- NO fake reservations or payments; no write endpoints, barcode generation,
  reservation binding, kitchen scheduling, tourism price enforcement,
  verified ledger integration or actual reception workflow yet.
- Migration is not deployed. Permission section identifiers and table schema
  must be reconciled with live app before deployment.
- Dashboard integration/code review remains unfinished; visual approval pending.
