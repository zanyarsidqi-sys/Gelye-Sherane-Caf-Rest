# Atomic prepaid allocation and motel-only journal

Upgrade creates one server RPC which calls the existing allocation and journal RPCs within one PostgreSQL statement/transaction. Failure of either step rolls back both. This is a dedicated motel-only journal, **not** the cafe numeric-order unified ledger. Invoice paid-state and dashboard certification remain blocked.

## Deployment
Apply prior migrations first, then this migration to isolated staging. Enable the existing Flutter staging flag only after migration, staging transaction tests, access checks, and owner approval. Never use a production receipt for a test. To test with psql, set `gs_test.receipt_id` to an independently verified fixture UUID in the same session and run the included diagnostics script as an authorized staging employee (not as postgres). Check first call and retry, then check persistent state after a committed test fixture separately. The included test uses `ROLLBACK` and cannot prove durability. Test unauthorized JWT, mismatched receipts, collisions, rollback injection and concurrent requests separately.

## Rollback
Disable `GS_ENABLE_VERIFIED_PREPAID_ALLOCATION`, then revoke execution on the new RPC. Preserve journal and allocation records; do not delete financial evidence. Do not roll back the previous migration automatically.
