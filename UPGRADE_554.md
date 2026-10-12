# Upgrade 554 — Legacy replacement RPC authorization hardening

Found a material financial-integrity gap: the five-argument `gs_replace_unaccepted_table_item` function from Upgrade 535 remains in PostgreSQL after Upgrade 538 adds the six-argument price-confirming overload. PostgreSQL overloads coexist, so authenticated clients could still call the older RPC without confirming the quoted price.

This migration revokes execution of the legacy overload from PUBLIC, anon, and authenticated while retaining the six-argument confirmed-price RPC for authenticated employees (subject to its internal permission checks). The legacy function is left in place to avoid destructive dependency changes. Privileged service-role access should be restricted operationally.

Static tests check the migration and confirmed-price implementation. These do not prove effective privileges in a live database. Apply the migration after 538, then verify `has_function_privilege` for anon/authenticated, verify legacy RPC fails, and verify confirmed RPC works with valid employee permissions and rejects stale prices.
