# Section 1 Dashboard — expanded source update

- Live Supabase KPI cards: order counts, cash receipts, outstanding order balances, tourism and kitchen activity.
- New table occupancy / seated guest cards based on configured gs_cafe_tables (not fabricated).
- Seven-day authorized order-count bar chart.
- Responsive card grid, date picker, refresh, loading and error states, permission-gated navigation.
- Migration 033 supersedes 032 dashboard RPC and adds gs_dashboard_week. Apply 031, 032, 033 in order after prerequisites.

## Verification outstanding
Flutter analyze/build unavailable in this environment; SQL not deployed or tested. Need test with employee roles, table records, cash ledger, dates and multiple screen widths. No claim of full production verification.
