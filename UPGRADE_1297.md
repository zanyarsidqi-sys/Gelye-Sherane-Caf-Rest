# Dashboard Upgrade 1297 — weekly cash value validation

- Reject malformed `cash_iqd` weekly trend values (strings, NaN and infinity) before rendering.
- Preserve null/omitted cash for permission-filtered responses, and legitimate signed numeric adjustments.
- Keep existing weekly order/date validation, retry UI, permissions, and all other sections intact.
- Archive/source checks performed; Flutter compilation and live Supabase integration remain unverified.
