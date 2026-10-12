# Upgrade 1280 — Dashboard weekly trend date-switch safety

- Added a date-mismatch loading guard to `_weekChart()` in `lib/screens/dashboard/dashboard_screen.dart`.
- During a queued business-day switch, the trend card now shows an accessible loading state instead of rendering the previous business day's weekly figures under the newly selected date.
- Reuses the existing `_loadingDay` and `_dateString()` tracking; no RPC signatures, permissions, financial data, or other sections changed.
- Verification: archive integrity, source guard assertion, and original-entry preservation. Flutter SDK/runtime and live Supabase tests unavailable.
