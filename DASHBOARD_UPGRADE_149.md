# Upgrade 149 — Two-session checkout concurrency test harness

Added `tools/test_checkout_row_lock_concurrency.py` to the full project.
It opens two independent PostgreSQL connections to a **staging** database,
locks the same existing order in the first session, confirms the second
session is rejected by `FOR UPDATE NOWAIT`, then rolls back the first
session and confirms the second can acquire the released lock.

Run with `pip install "psycopg[binary]"`, then set `TEST_DATABASE_URL`
(staging only) and `CONFIRM_STAGING=YES`; run
`python tools/test_checkout_row_lock_concurrency.py`.

This is a real two-session **lock primitive** test, not a checkout/payment
integration test. It does not create orders, collect payments, enable the
mixed-checkout feature gate, or certify the release RPC's lock ordering.
Live Supabase tests have not been run. Production mixed release stays disabled.
