# Upgrade 1152 — Kitchen transaction smoke test

Added `supabase/verification/kitchen_1152_transition_smoke.sql`, a staging-only
**transactional behavioral test** of the Kitchen `new -> preparing -> ready -> served`
workflow, reopening rejection, and served-item deletion prevention.

Example (staging only):

```sh
psql "$STAGING_DATABASE_URL" -v test_order_id=123 -v test_employee_uuid=00000000-0000-0000-0000-000000000000 -f supabase/verification/kitchen_1152_transition_smoke.sql
```

Replace example values with a disposable NEW order with valid items and a real
Kitchen editor. The script wraps changes in BEGIN/ROLLBACK, but **do not run in
production** because RPCs can cause side effects beyond the database transaction.
This smoke test does not prove cross-session concurrency or full acceptance.

Not executed against Supabase in this environment. Live acceptance remains 0/5.
