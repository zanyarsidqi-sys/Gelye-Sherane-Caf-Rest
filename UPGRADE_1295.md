# Dashboard Upgrade 1295

Project: Gelye Sherane Café & Restaurant

## Change
- Sort validated weekly trend rows chronologically by ISO business day before handing them to the chart.
- Prevent out-of-order Supabase rows from displaying a misleading trend or cash breakdown.
- Preserve existing seven-day validation, retry/error handling, access control, and all other project files.

## Verification
- Archive CRC verification, unchanged-entry byte comparison, and source assertions performed.
- Flutter compilation, device tests and live Supabase integration remain unverified because the SDK and backend credentials are unavailable.
