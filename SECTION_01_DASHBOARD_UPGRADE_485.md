# Upgrade 485 — Dashboard cash collections reporting

- Added a permission-safe copyable cash collections report.
- Shows receipt counts only for ledger scopes returned by Supabase.
- Shows combined cash collections **only if both scopes are accessible and valid**.
- Distinguishes unreconciled cash collections from revenue/profit and excludes credit.
- No database migration or new credit payment capability.
- Section 01 remains **83% provisional development estimate**.
- Flutter compilation, live Supabase testing, and accounting reconciliation not performed.
