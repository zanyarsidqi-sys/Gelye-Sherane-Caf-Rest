# Upgrade 478 — Dashboard weekly SQL correctness fix

- Corrected a PostgreSQL date arithmetic bug in migration 474: timestamp + integer is invalid.
- Returned business_date as YYYY-MM-DD to match Flutter validation instead of a timestamp string.
- Returns an empty array if neither table nor motel order permissions are granted, preventing misleading zero counts.
- Retains dashboard permission checks, Baghdad-local day boundaries and read-only aggregates.
- No Flutter compilation, live migration or end-to-end test performed.
- Section 01 progress remains 80% provisional pending live verification and financial KPI work.
