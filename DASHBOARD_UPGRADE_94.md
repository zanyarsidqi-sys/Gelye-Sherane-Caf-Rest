# Dashboard Upgrade 94 — Visit-scoped checkout guard

**Code change:** Replaced `gs_table_checkout_readiness` with a stricter read-only
version. Outstanding cleaning and shisha task counts now use the active
`table_visit_id`, rather than mixing old visits on the same physical table.

**Fail-closed legacy checks:** Outstanding tasks without a visit ID, and
historical orders without a visit ID, now explicitly block release pending
manual reconciliation. Pending guest moves and unconfirmed departure also
block. The function always returns `checkout_authorized=false`.

This does not authorize table checkout or implement automatic release.
Verified settlement, departure/cleaning workflow, actual bill transfer,
legacy migration safety and Supabase staging tests remain outstanding.

**Verification:** ZIP CRC and duplicate-entry checks passed. SQL was not
executed against Supabase and Flutter was not compiled.
