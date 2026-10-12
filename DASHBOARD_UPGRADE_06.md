# Dashboard Coding Upgrade 06

Added permission-gated optional KPI cards for table and motel order statuses (waiting, preparing, delivered), reservation statuses (not arrived, arrived, late, no-show, upcoming). These render only when the authorized `gs_dashboard_overview` RPC returns their respective keys; no numbers are invented. Table detail action now checks `tables` permission.

## Still pending

- Supabase RPC migrations/authorization and real status aggregation (keys currently optional).
- Extra-chair and late-arriving guest persistence, individual bills, and customer name editing.
- Transaction-level drilldowns, full live table layout, Flutter compilation, database tests.
- Visual approval of Section 01.

No PC verification performed. Overall Phase 3 remains approximately 54% (prior estimate, not independently verified).
