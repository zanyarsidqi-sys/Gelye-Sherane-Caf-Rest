# Upgrade 1153 — Kitchen denied-employee smoke test

Adds a staging-only psql test for an employee **without** Kitchen `can_edit`.
It asserts the status RPC rejects the employee for the expected authorization
reason and leaves the order unchanged. The transaction rolls back.

Run with `psql -v ON_ERROR_STOP=1 -v test_order_id=<disposable-id>
-v denied_employee_uuid=<authenticated-employee-without-kitchen-edit>
-f supabase/verification/kitchen_1153_authorization_smoke.sql`.

The existing positive-path smoke test from 1152 requires a separate employee
WITH Kitchen `can_edit`. These are test fixtures, not verified live results.

Source tests only; live Supabase and Flutter checks are deferred.
