# Phase 3 — Revenue workspace update

- Added a separate read-only Supabase order-value tab and retained the local preview tab.
- Filter by Normal/Tourism and show non-cancelled, cancelled, and mode-specific order values.
- Uses authenticated gs_orders and gs_order_items queries, subject to RLS; no database changes.
- Explicitly warns that order value is not cash received, recognized revenue, or profit.
- Data is capped at 100 orders and 1,000 items and can be incomplete. No financial totals should be treated as authoritative.
- Flutter analyze and live Supabase testing remain pending.
