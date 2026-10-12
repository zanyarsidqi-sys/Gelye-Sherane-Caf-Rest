# Dashboard Upgrade 97 — Visit-wide settlement aggregation fix

**Code correction:** Replaced the visit settlement gate implementation to use
separate `v_order` and `v_summary` records when iterating through orders.
The previous implementation reused one record variable for the cursor and
`SELECT INTO`, which risked corrupting iteration and aggregation.

**Additional checks:** Excludes cancelled orders from provisional totals,
rejects missing reconciliation summaries, and continues to identify legacy
orders without a visit link. The returned amounts are **provisional only**.

**No checkout release:** `all_orders_financially_verified` and
`checkout_allowed` both remain false, even for a zero apparent balance.
No guest departure, table release, cash settlement, bill transfer or
financial posting is executed.

**Verification:** ZIP structure and source checks only; no PostgreSQL staging
execution, Flutter build, or concurrency testing. Next prioritize an
end-to-end tested payment posting and visit settlement implementation.
