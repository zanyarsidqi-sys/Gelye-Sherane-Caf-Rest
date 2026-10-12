# Upgrade 477 — Dashboard weekly integrity and recovery

- Validates that the weekly activity RPC returns unique, ISO-formatted business dates; duplicate dates now fail closed instead of inflating counts.
- Sorts the returned dates chronologically, regardless of database response ordering.
- Adds average orders per reported day, explicitly avoiding a misleading seven-day denominator if some dates are missing.
- Adds a retry action when weekly data fails to load.
- Does not introduce financial estimates, credit debits, or permission bypasses.
- Section 01 provisional development progress: 80% (up from 79%); this is not verified completion.
- Flutter compilation and live Supabase tests remain pending.
