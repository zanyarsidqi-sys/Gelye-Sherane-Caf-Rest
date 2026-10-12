# Upgrade 1459 — Credit-posting response integrity

The staged Flutter credit posting action now verifies the authenticated employee has not changed during the confirmation/RPC round-trip, and requires valid journal/account UUIDs, a positive integer charge amount, and a boolean `already_posted` field. Duplicate idempotent responses are described as already recorded, not as new charges. Any malformed response fails closed; the caller must inspect the journal before retrying after a timeout.

**Not included:** source-backed café-to-motel identity, prepaid allocation, invoice paid state, unified ledger posting, certified Dashboard IQD totals. No production posting is enabled by this upgrade.

**Staging gate:** apply migrations on isolated staging; test permissions, initial charge, idempotent repeat, mismatched key, concurrent same request, concurrent different requests on same invoice, insufficient limit, cash collision, transaction rollback and unchanged account balance on failure. Run Flutter analyze/build and verify screen navigation on target platforms. Do not set `GS_ENABLE_VERIFIED_CREDIT_POSTING=true` before all tests pass. No live staging access or Flutter toolchain was available during packaging.
