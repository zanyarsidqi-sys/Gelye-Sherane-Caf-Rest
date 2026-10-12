# Dashboard Upgrade 54 — Visit-specific cleaning safety review

- Added a trigger to reject service tasks whose visit belongs to another table.
- Added `gs_dashboard_visit_cleaning_status(visit_id)` to inspect cleaning and
  shisha task completion for exactly one visit.
- Detects unlinked legacy tasks and orders, and reports them as blockers.
- Never labels a visit payment-cleared or automatically releases the table.
- Explicitly distinguishes task completion from verified financial settlement.

CRITICAL REMAINING: legacy checkout/release RPCs still use table numbers and
cash-only checks. They must be replaced and audited before any live deployment.
New task-creation and checkout workflows must set `table_visit_id` on every
service task; historical records must be reviewed, never guessed/backfilled.
Shisha pickup obligation needs an authoritative per-visit flag. No live SQL,
Flutter compile, integration tests, or migration deployment performed.
