# Upgrade 1292 — Dashboard weekly order count validation

- Reject non-finite, fractional, and negative order counts from `gs_dashboard_week` before rendering the chart.
- Preserve null counts and existing chart behavior for valid whole nonnegative values.
- Existing error UI and Retry trend action handle rejected payloads.
- Source checks and ZIP integrity performed; Flutter compilation and live Supabase tests not available in this environment.
