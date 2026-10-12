# Dashboard Upgrade 45 — Guarded Table Release (DRAFT)

Added SQL migration 046, `gs_release_cleaned_cafe_table`:
- Requires authorized employee, occupied table, recorded guest departure and cleaning-needed flag.
- Requires a completed cleaning task from the current departure period.
- Rejects pending cleaning/shisha pickup and any uncompleted shisha pickup created after departure.
- Rechecks active orders and cash-only settlement before release.
- Resets occupancy, guest count, tourism mode and cleaning flags only after checks pass.
- Legacy release RPC remains blocked while cleaning is required.

NOT production ready: task history is not linked to a unique visit/session;
noncash payments are not supported; full release audit, race-condition review,
live SQL validation, and Flutter action UI are pending.
No automatic table release was added: release is an explicit authorized action.
