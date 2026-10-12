# Dashboard Coding Upgrade 28 — Operational Metrics (draft)

Added draft migration `20261009_037_dashboard_operational_metrics_draft.sql` and optional RPC merge in `dashboard_screen.dart`.

Metrics with database-backed definitions:
- `table_occupancy_percent`: occupied configured tables / all configured tables. Omitted when no tables configured.
- `overdue_service_orders`: currently new/preparing/ready orders created on selected Baghdad-local day and older than 30 minutes; only visible permitted order categories. 30-minute threshold is provisional.
- `top_product_units_sold`: maximum units sold for any one product on selected day, excluding cancelled orders; limited to permitted order categories. This is **not** total units across products.
- `urgent_actions_count`: unresolved urgent guest feedback only, not all possible urgent actions. Requires Action Center and Customers view permissions.

Not yet connected: cash reconciliation discrepancies, employee attendance, maintenance issues, offline sync counts. These keys remain absent rather than returning misleading zeroes.

No SQL migration has been deployed or tested. The Flutter project has not been compiled. Validate permission keys, schema and metrics on a PC before enabling in production. Existing Dashboard overview remains available if the optional RPC is unavailable.
