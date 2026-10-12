# Dashboard Coding Upgrade 26 — Operational intelligence KPI scaffolding

Added eight KPI definitions in dashboard_screen.dart:
- Urgent actions
- Overdue service orders
- Cash discrepancies
- Employees on duty
- Top product units sold
- Table occupancy percentage
- Open maintenance issues
- Pending offline sync items

Each card is rendered only if the signed-in employee has the relevant section permission AND the existing permission-filtered `gs_dashboard_overview` RPC actually returns a numeric metric. Thus no sample numbers or false live statuses appear. Cards use the existing click-to-detail and individual color/reorder editor, with iPhone full-screen and Windows side-panel detail behavior.

Important: This does NOT implement the eight server-side metric computations or new backend authorization; exact permission keys must be reconciled with the deployed section registry. Missing metrics remain hidden. Backend migration, audit trail, role enforcement, card resizing, cross-device sync, AI, and verification remain pending. This is an incremental coding change, not a production readiness claim.

Tests deferred per user's temporary no-PC coding-only request. No Flutter compile or live Supabase test performed.
