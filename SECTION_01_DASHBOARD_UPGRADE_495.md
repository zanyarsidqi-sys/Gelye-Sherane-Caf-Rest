# Upgrade 495 — Dashboard daily cash rendering validation

Fixed a financial integrity issue: the seven-day cash UI previously rendered any non-null per-day amount even if negative, fractional, nonfinite, or inconsistent with receipt counts. Each displayed daily amount now validates the cash amount and receipt count as a pair and renders Restricted / invalid otherwise. Daily receipt counts are shown beside amounts for auditability. Removed duplicate spacing.

No database migrations. No credit debits enabled. Dashboard coding progress stays at 84% provisional. Flutter analyzer, builds, and live Supabase verification have not run.
