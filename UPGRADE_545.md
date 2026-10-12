# Upgrade 545 — Kitchen receipt audit integrity

Section 03 Table Orders. Builds on Upgrade 544.

- Receipt audit and dispatch status now change within the same PostgreSQL transaction.
- Acknowledged revisions without an audit record raise an explicit integrity error instead of reporting success.
- Unacknowledged revisions with an existing receipt audit are blocked pending administrative reconciliation.
- Idempotent repeat acknowledgment returns the original employee identity from the audit record.
- Preserves kitchen permissions, replacement-only checks, failed-dispatch guard and existing interfaces.

## Deployment and verification

Apply `20261010_545_kitchen_receipt_audit_integrity.sql` after migrations 539–544. Existing inconsistent rows require manual review; this migration intentionally does not rewrite financial or kitchen history.

ZIP structure and SQL text were checked locally. Flutter compilation and live Supabase migration/integration tests were **not** run.
