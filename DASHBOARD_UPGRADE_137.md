# Upgrade 137 — Protected mixed-payment release (disabled by default)

Implements an MFA/permission-protected release RPC using table→visit→order
row locking, per-order attestation coverage, cancelled-order financial
checks, mixed-payment re-reconciliation, physical checkout checks,
audited visit closure, and table reset.

**SAFETY:** `gs_mixed_checkout_feature_gate.enabled` defaults to FALSE.
Do not enable until actual provider webhook/API verification exists and
staging schema, order payment guards, concurrency, audit and release tests
have passed. Existing cash-only release is untouched. This ZIP has not
been deployed or Flutter-compiled; this is unverified SQL source.
