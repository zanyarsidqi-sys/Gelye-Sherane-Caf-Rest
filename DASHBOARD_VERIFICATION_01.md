# Section 1 — Dashboard redesign and live figures

- Replaces local demonstration data with `gs_dashboard_overview` RPC.
- Apply migration `supabase/migrations/20261009_031_dashboard_live_overview.sql` after 001 and 021.
- The RPC checks dashboard permission and returns each group of figures only if the user has the corresponding section permission. UI hides absent fields.
- Iraq local dates, order value distinct from cash collected, cash outstanding across orders created on selected date.
- Selected-date cash collected means cash payment timestamp falls on that date, not necessarily order date.
- Excludes cancelled orders from order value and outstanding totals; raw orders count includes cancelled orders.
- Responsive two/three/four column layout, dark theme inherited, pull-to-refresh, date picker, loading/error states, authorized navigation.
- No fake zeros on missing connection. No card/credit amounts or invented revenue.
- Remaining verification: Flutter analyze/build on user machine, migration deploy, Supabase permissions and figures, responsive iPhone/Windows, real accounting reconciliation.
- NOTE: the top-level ManagementDashboard in cafe_app.dart is the section navigation home. Open the Dashboard section card to view the redesigned business dashboard.
