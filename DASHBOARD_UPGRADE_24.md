# Dashboard coding upgrade 24 — Command Center foundation

## Implemented in Flutter source
- Added Manager / Cashier / Waiter / Kitchen focus selector to Dashboard.
- Each focus has a priority order for existing live KPI cards. Existing employee card-order overrides win.
- Mode is stored in existing per-account local preferences. This is NOT role authorization or cloud synchronization.
- Existing backend-filtered permissions remain the only access boundary; switching focus does not grant rights.

## Approved design requirements — not yet implemented
- Action Center & Urgent Alerts; Service Speed; Cashier Reconciliation; Employee Attendance;
  Product Performance; Table Occupancy; Maintenance; System Health.
- AI recommendations with source evidence and approval gates; complete cross-section audit trail;
  drag-and-drop, card sizing, cross-device personalization, realtime subscriptions.
- iPhone full-screen and Windows side-panel detail views for all cards.

## Deferred verification
Flutter analysis/tests, Supabase RLS/RPC integration, online/offline reconciliation and device UI screenshots.
No invented metric values or unverified server-side actions are included.
