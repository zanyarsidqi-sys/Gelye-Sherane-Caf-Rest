# Upgrade 492 — Dashboard cash trend freshness guard

- Validates that the seven consecutive cash-report dates end on the current Iraq business date (UTC+03).
- Applies the same date validation before exporting the report to the clipboard.
- Prevents a stale or truncated seven-day cash report from being presented as current.
- Retains restricted-value behavior and unreconciled financial labels.

## Verification
Static source checks and ZIP integrity only. Flutter compilation and live Supabase testing remain outstanding. Dashboard development progress remains 84% estimated.
