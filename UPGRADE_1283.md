# Dashboard Upgrade 1283

## Implemented
- Corrected pull-to-refresh completion: RefreshIndicator now awaits the coordinated overview and weekly-trend request cycle, including any queued business-day follow-up, rather than awaiting a potentially stale `_overview` future.
- Added a small list of completion waiters; complete them after the refresh lock is released without another queued request, and on Dashboard disposal to avoid dangling spinners.
- No changes to RPC definitions, permissions, card content, or other sections.

## Verification
- ZIP integrity and retained archive entries checked; targeted source assertions passed.
- Flutter SDK / live Supabase unavailable; compilation and runtime behavior remain unverified.
